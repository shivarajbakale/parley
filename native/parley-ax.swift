// Reads the focused UI element through the macOS Accessibility API and prints
// one JSON object: { role, subrole, bundleId, editable, valueKnown, value,
// valueOffset, valueLength, caret, selectedText, secure, selectionBounds }.
// A value longer than `valueWindow` (a terminal's scrollback, a long document)
// is printed only around the caret: `value` starts at `valueOffset` in the
// whole, which is `valueLength` long. Offsets and lengths count UTF-16 units.
// With `--window-only` it prints just { frontWindowBounds } and never touches the
// focused field: the orb only needs to know where the window is, and a field's
// whole value (a terminal's scrollback) is too much output to wait for.
//
// Read-only on purpose. Writing AXValue into a web input skips the page's own
// input events, so Parley always writes back with a real paste instead. The
// one write is `--select <location> <length>`, which moves the selection so
// that paste lands on one paragraph of a long document; it prints
// { selected: true|false } and changes no text.
//
// Runs as a child of Parley, so it rides on Parley's Accessibility grant.

import AppKit
import ApplicationServices

let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
  var value: AnyObject?
  return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func focusedElement() -> AXUIElement? {
  let system = AXUIElementCreateSystemWide()
  AXUIElementSetMessagingTimeout(system, 1.0)
  if let focused = attribute(system, kAXFocusedUIElementAttribute) {
    return (focused as! AXUIElement)
  }
  // Electron apps build their accessibility tree only when asked to.
  guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
  let application = AXUIElementCreateApplication(front.processIdentifier)
  AXUIElementSetMessagingTimeout(application, 1.0)
  AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
  if let focused = attribute(application, kAXFocusedUIElementAttribute) {
    return (focused as! AXUIElement)
  }
  return nil
}

/// Where the selection sits on screen, in the same top-left coordinates Electron uses.
func selectionBounds(_ element: AXUIElement) -> [String: Double]? {
  guard let range = attribute(element, kAXSelectedTextRangeAttribute) else { return nil }
  var bounds: AnyObject?
  guard
    AXUIElementCopyParameterizedAttributeValue(
      element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &bounds) == .success,
    let value = bounds, CFGetTypeID(value) == AXValueGetTypeID()
  else { return nil }
  var rect = CGRect.zero
  guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
  return ["x": rect.origin.x, "y": rect.origin.y, "width": rect.size.width, "height": rect.size.height]
}

/// The frontmost app's key window, in the same top-left coordinates Electron
/// uses. This is what "which window is the user on" means: the mouse can be
/// resting on another display entirely.
func frontWindowBounds() -> [String: Double]? {
  guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
  let application = AXUIElementCreateApplication(front.processIdentifier)
  AXUIElementSetMessagingTimeout(application, 1.0)
  // Electron apps build their accessibility tree only when asked to; without
  // this the first read of their window comes back empty.
  AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
  guard
    let window = attribute(application, kAXFocusedWindowAttribute)
      ?? attribute(application, kAXMainWindowAttribute)
  else { return nil }
  guard
    let positionValue = attribute(window as! AXUIElement, kAXPositionAttribute),
    let sizeValue = attribute(window as! AXUIElement, kAXSizeAttribute)
  else { return nil }
  var point = CGPoint.zero
  var size = CGSize.zero
  guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) else { return nil }
  guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
  return ["x": point.x, "y": point.y, "width": size.width, "height": size.height]
}

func emit(_ object: [String: Any]) -> Never {
  let data = try! JSONSerialization.data(withJSONObject: object)
  FileHandle.standardOutput.write(data)
  exit(0)
}

guard AXIsProcessTrusted() else { emit(["error": "untrusted"]) }

/// The caret or selection as a UTF-16 range in the element's whole value.
func selectedRange(_ element: AXUIElement) -> CFRange? {
  guard let value = attribute(element, kAXSelectedTextRangeAttribute),
    CFGetTypeID(value) == AXValueGetTypeID()
  else { return nil }
  var range = CFRange()
  return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
}

/// Each side of the caret printed for a value too long to print whole.
let valueWindow = 20_000

if let at = CommandLine.arguments.firstIndex(of: "--select") {
  let numbers = CommandLine.arguments.dropFirst(at + 1).prefix(2).compactMap { Int($0) }
  guard numbers.count == 2, let element = focusedElement() else { emit(["selected": false]) }
  var range = CFRange(location: numbers[0], length: numbers[1])
  guard let value = AXValueCreate(.cfRange, &range) else { emit(["selected": false]) }
  let result = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
  emit(["selected": result == .success])
}

let windowBounds = frontWindowBounds()
if CommandLine.arguments.contains("--window-only") {
  emit(["frontWindowBounds": windowBounds as Any? ?? NSNull()])
}
guard let element = focusedElement() else {
  emit(["error": "no_focus", "frontWindowBounds": windowBounds as Any? ?? NSNull()])
}

let role = attribute(element, kAXRoleAttribute) as? String ?? ""
let subrole = attribute(element, kAXSubroleAttribute) as? String ?? ""

var settable: DarwinBoolean = false
AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)

// A password field's value is never Parley's to read.
let secure = subrole == "AXSecureTextField"
let editable = !secure && (textRoles.contains(role) || settable.boolValue)

// An empty string is an answer ("the field is empty"); no string at all means
// the app would not say, and only then is the keystroke fallback worth its risk.
let value = editable ? attribute(element, kAXValueAttribute) as? String : nil
let caret = secure ? nil : selectedRange(element)

let whole = (value ?? "") as NSString
var shown = NSRange(location: 0, length: whole.length)
if whole.length > 2 * valueWindow {
  let center = min(max(caret?.location ?? whole.length, 0), whole.length)
  let start = max(0, center - valueWindow)
  let end = min(whole.length, center + valueWindow)
  // Never cut an emoji or a combined character in half.
  shown = whole.rangeOfComposedCharacterSequences(for: NSRange(location: start, length: end - start))
}

emit([
  "role": role,
  "subrole": subrole,
  "bundleId": NSWorkspace.shared.frontmostApplication?.bundleIdentifier as Any? ?? NSNull(),
  "editable": editable,
  "valueKnown": value != nil,
  "value": whole.substring(with: shown),
  "valueOffset": shown.location,
  "valueLength": whole.length,
  "caret": caret.map { ["location": $0.location, "length": $0.length] } as Any? ?? NSNull(),
  // The selection is read for any element that is not a password field: Explain
  // works on text the user cannot edit. Voice edit still gates on `editable`.
  "selectedText": secure ? "" : (attribute(element, kAXSelectedTextAttribute) as? String ?? ""),
  "secure": secure,
  "selectionBounds": (secure ? nil : selectionBounds(element)) as Any? ?? NSNull(),
  "frontWindowBounds": windowBounds as Any? ?? NSNull(),
])
