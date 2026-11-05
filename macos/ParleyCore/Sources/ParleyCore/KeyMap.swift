/// Key events as the engine's gesture detector expects them: the names in
/// `GESTURE_KEYS` (electron/types.ts), plus Escape and Other.
///
/// Modifiers arrive from a CGEventTap as `flagsChanged`, which says only that
/// some modifier changed. The device-dependent bits in the flags tell left
/// from right and down from up, so a bare Right Option press is visible —
/// the thing Electron's globalShortcut could never see.
public struct KeyTransition: Equatable, Sendable {
    public enum Kind: String, Sendable { case down, up }
    public let kind: Kind
    public let key: String

    public init(_ kind: Kind, _ key: String) {
        self.kind = kind
        self.key = key
    }
}

public enum KeyMap {
    /// Virtual key code → (gesture key name, device-dependent flag bit).
    /// Bits are the NX_DEVICE*KEYMASK values from IOKit's IOLLEvent.h.
    static let modifiers: [UInt16: (name: String, mask: UInt64)] = [
        58: ("Alt", 0x0000_0020),
        61: ("AltRight", 0x0000_0040),
        59: ("Ctrl", 0x0000_0001),
        62: ("CtrlRight", 0x0000_2000),
        56: ("Shift", 0x0000_0002),
        60: ("ShiftRight", 0x0000_0004),
        55: ("Meta", 0x0000_0008),
        54: ("MetaRight", 0x0000_0010),
    ]

    public static let escapeKeyCode: UInt16 = 53

    /// A non-modifier key. Auto-repeat downs pass through; the detector
    /// treats any Other as a reset, so repeats are harmless.
    public static func key(_ kind: KeyTransition.Kind, keyCode: UInt16) -> KeyTransition {
        KeyTransition(kind, keyCode == escapeKeyCode ? "Escape" : "Other")
    }

    public static func isModifier(_ keyCode: UInt16) -> Bool {
        modifiers[keyCode] != nil
    }
}

/// Turns `flagsChanged` events into downs and ups, deduplicated: macOS can
/// send a flagsChanged for a modifier whose state did not move (e.g. caps
/// lock toggling alongside), and the detector must see each edge once.
public struct ModifierTracker: Sendable {
    private var down: Set<UInt16> = []
    public init() {}

    public mutating func flagsChanged(keyCode: UInt16, flags: UInt64) -> KeyTransition? {
        guard let modifier = KeyMap.modifiers[keyCode] else {
            // Caps Lock, Fn, and friends: a key the detector should see as
            // "something else was pressed".
            return KeyTransition(.down, "Other")
        }
        let isDown = flags & modifier.mask != 0
        if isDown {
            guard down.insert(keyCode).inserted else { return nil }
            return KeyTransition(.down, modifier.name)
        }
        guard down.remove(keyCode) != nil else { return nil }
        return KeyTransition(.up, modifier.name)
    }

    /// The tap was disabled and re-enabled: anything held may have been
    /// released unseen.
    public mutating func reset() {
        down.removeAll()
    }
}
