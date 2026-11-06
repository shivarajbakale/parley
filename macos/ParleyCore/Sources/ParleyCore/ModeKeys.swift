/// The four modes' gesture keys, as the settings window edits them.
///
/// Recording a key that another mode already uses swaps the two, the way
/// Raycast resolves a taken hotkey: no mode is ever left switched off by a
/// duplicate, and the user never has to fix two rows to change one.
public enum ModeKeys {
    /// Settings fields in priority order: on a duplicate the engine keeps the earlier mode.
    public static let fields = ["gestureKey", "editGestureKey", "explainGestureKey", "actGestureKey"]

    /// The settings patch that gives `field` the key `key`. A mode holding
    /// `key` already takes `field`'s old key, or a free key if the old one
    /// is itself still in use (the settings held a duplicate).
    public static func assign(_ key: GestureKeyName, to field: String, current: [String: GestureKeyName]) -> [String: GestureKeyName] {
        guard let old = current[field], old != key else { return [:] }
        var patch = [field: key]
        guard let displaced = fields.first(where: { $0 != field && current[$0] == key }) else { return patch }
        var after = current
        after[field] = key
        after[displaced] = nil
        let taken = Set(after.values)
        if !taken.contains(old) {
            patch[displaced] = old
        } else if let free = GestureKeyName.allCases.first(where: { !taken.contains($0) }) {
            patch[displaced] = free
        }
        return patch
    }
}

extension GestureKeyName {
    /// The modifier a virtual key code names, or nil for any other key.
    public init?(keyCode: UInt16) {
        guard let name = KeyMap.modifiers[keyCode]?.name else { return nil }
        self.init(rawValue: name)
    }

    /// Just the symbol, for a keycap.
    public var symbol: String {
        switch self {
        case .AltRight, .Alt: "⌥"
        case .CtrlRight, .Ctrl: "⌃"
        case .ShiftRight, .Shift: "⇧"
        case .MetaRight, .Meta: "⌘"
        }
    }

    /// "Right Option", without the symbol.
    public var name: String {
        String(label.dropLast(2))
    }
}
