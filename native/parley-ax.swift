// Reads the focused UI element through the macOS Accessibility API and prints
// one JSON object: { role, subrole, editable, valueKnown, value, selectedText }.
//
// Read-only on purpose. Writing AXValue into a web input skips the page's own
// input events, so Parley always writes back with a real paste instead.
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

func emit(_ object: [String: Any]) -> Never {
  let data = try! JSONSerialization.data(withJSONObject: object)
  FileHandle.standardOutput.write(data)
  exit(0)
}

guard AXIsProcessTrusted() else { emit(["error": "untrusted"]) }
guard let element = focusedElement() else { emit(["error": "no_focus"]) }

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

emit([
  "role": role,
  "subrole": subrole,
  "editable": editable,
  "valueKnown": value != nil,
  "value": value ?? "",
  "selectedText": editable ? (attribute(element, kAXSelectedTextAttribute) as? String ?? "") : "",
])
