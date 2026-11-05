import AppKit
import ApplicationServices
import AVFoundation

/// Microphone and Accessibility, asked of Parley.app itself. The engine never
/// touches either: it only hears what the shell reports.
struct PermissionState: Equatable {
    var microphone: Bool
    var accessibility: Bool

    static func current() -> PermissionState {
        PermissionState(
            microphone: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            accessibility: AXIsProcessTrusted()
        )
    }
}

enum Permissions {
    static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            openSettings(anchor: "Privacy_Microphone")
            return false
        }
    }

    private static let promptedKey = "accessibilityPrompted"

    /// The system prompt only once, ever: it adds Parley to the list. After
    /// that, asking again just opens the pane, never a second dialog.
    static func requestAccessibility() {
        guard !AXIsProcessTrusted() else { return }
        if !UserDefaults.standard.bool(forKey: promptedKey) {
            UserDefaults.standard.set(true, forKey: promptedKey)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        } else {
            openSettings(anchor: "Privacy_Accessibility")
        }
    }

    static func openSettings(anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
