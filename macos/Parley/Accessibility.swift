import AppKit
import ApplicationServices
import ParleyCore

/// The focused field through the Accessibility API, in-process. A port of the
/// old `parley-ax` helper: same answers, same JSON shape, so the engine's
/// `parseFocusedField` (and its tests) still decide what counts as a field,
/// without spawning a process per read.
///
/// Read-only except `select`, which moves the selection so a paste lands on
/// one paragraph of a long document. Writing AXValue directly would skip a web
/// page's own input events; Parley always writes with a real paste.
///
/// Every call can block on a slow app for up to the messaging timeout, so
/// callers run these off the main thread.
enum Accessibility {
    static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
    /// Each side of the caret returned for a value too long to return whole.
    static let valueWindow = 20_000
    static let messagingTimeout: Float = 1.0

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, messagingTimeout)
        if let focused = attribute(system, kAXFocusedUIElementAttribute) {
            return (focused as! AXUIElement)
        }
        // Electron and Chromium apps build their accessibility tree only when asked.
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let application = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(application, messagingTimeout)
        AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        if let focused = attribute(application, kAXFocusedUIElementAttribute) {
            return (focused as! AXUIElement)
        }
        return nil
    }

    /// Top-left-origin screen coordinates, as the engine and AX use them.
    private static func rect(_ value: AnyObject?) -> CGRect? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(value as! AXValue, .cgRect, &rect) ? rect : nil
    }

    private static func json(_ rect: CGRect?) -> JSONValue {
        guard let rect else { return .null }
        return ["x": .number(rect.origin.x), "y": .number(rect.origin.y),
                "width": .number(rect.width), "height": .number(rect.height)]
    }

    private static func selectionBounds(_ element: AXUIElement) -> CGRect? {
        guard let range = attribute(element, kAXSelectedTextRangeAttribute) else { return nil }
        var bounds: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &bounds) == .success
        else { return nil }
        return rect(bounds)
    }

    /// The frontmost app's key window: the window the user is on, which can be
    /// on a different display than the mouse.
    static func frontWindowBounds() -> CGRect? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let application = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(application, messagingTimeout)
        AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        guard let window = attribute(application, kAXFocusedWindowAttribute)
            ?? attribute(application, kAXMainWindowAttribute)
        else { return nil }
        guard let positionValue = attribute(window as! AXUIElement, kAXPositionAttribute),
              let sizeValue = attribute(window as! AXUIElement, kAXSizeAttribute)
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: point, size: size)
    }

    private static func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute),
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        var range = CFRange()
        return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
    }

    /// `{error}` or the field, in the helper's old shape.
    static func focusedField() -> JSONValue {
        guard AXIsProcessTrusted() else { return ["error": "untrusted"] }
        let window = json(frontWindowBounds())
        guard let element = focusedElement() else { return ["error": "no_focus", "frontWindowBounds": window] }

        let role = attribute(element, kAXRoleAttribute) as? String ?? ""
        let subrole = attribute(element, kAXSubroleAttribute) as? String ?? ""
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)

        // A password field's value is never Parley's to read.
        let secure = subrole == "AXSecureTextField"
        let editable = !secure && (textRoles.contains(role) || settable.boolValue)
        // An empty string is an answer ("the field is empty"); nil means the
        // app would not say.
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

        let bundleId: JSONValue = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.map { .string($0) } ?? .null
        let caretJSON: JSONValue = caret.map { ["location": .number(Double($0.location)), "length": .number(Double($0.length))] } ?? .null
        return [
            "role": .string(role),
            "subrole": .string(subrole),
            "bundleId": bundleId,
            "editable": .bool(editable),
            "valueKnown": .bool(value != nil),
            "value": .string(whole.substring(with: shown)),
            "valueOffset": .number(Double(shown.location)),
            "valueLength": .number(Double(whole.length)),
            "caret": caretJSON,
            // Explain reads the selection of text the user cannot edit too.
            "selectedText": .string(secure ? "" : (attribute(element, kAXSelectedTextAttribute) as? String ?? "")),
            "secure": .bool(secure),
            "selectionBounds": secure ? .null : json(selectionBounds(element)),
            "frontWindowBounds": window,
        ]
    }

    static func select(location: Int, length: Int) -> Bool {
        guard AXIsProcessTrusted(), let element = focusedElement() else { return false }
        var range = CFRange(location: location, length: length)
        guard let value = AXValueCreate(.cfRange, &range) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success
    }
}
