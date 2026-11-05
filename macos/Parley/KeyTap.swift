import CoreGraphics
import Foundation
import ParleyCore

/// A listen-only CGEventTap: sees every key and modifier edge, swallows
/// nothing. Installed on the main run loop, so the callback runs on main.
///
/// The callback only translates and forwards; macOS disables a tap whose
/// callback is slow, and re-enabling it is handled here.
final class KeyTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var tracker = ModifierTracker()

    /// (transition, milliseconds since boot) — the engine's detector only
    /// compares differences, so any monotonic clock works.
    var onTransition: (KeyTransition, Double) -> Void = { _, _ in }

    var isRunning: Bool { tap != nil }

    /// False when macOS refused the tap: Accessibility (or Input
    /// Monitoring) is not granted yet.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: keyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = runLoopSource
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        tap = nil
        source = nil
        tracker.reset()
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            tracker.reset()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        default:
            break
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let time = Double(event.timestamp) / 1_000_000
        let transition: KeyTransition?
        switch type {
        case .flagsChanged:
            transition = tracker.flagsChanged(keyCode: keyCode, flags: event.flags.rawValue)
        case .keyDown:
            transition = KeyMap.key(.down, keyCode: keyCode)
        case .keyUp:
            transition = KeyMap.key(.up, keyCode: keyCode)
        default:
            transition = nil
        }
        if let transition { onTransition(transition, time) }
    }
}

private func keyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        Unmanaged<KeyTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
    }
    return Unmanaged.passUnretained(event)
}
