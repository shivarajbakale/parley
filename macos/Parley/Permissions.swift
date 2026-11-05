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

    /// Shows the system prompt the first time; after that, opens the pane.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            openSettings(anchor: "Privacy_Accessibility")
        }
    }

    static func openSettings(anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
