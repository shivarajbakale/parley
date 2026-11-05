import AppKit
import AVFoundation
import os
import Security
import ServiceManagement

/// The key that encrypts the sync token at rest. 32 random bytes, created
/// once and kept in the login Keychain; the engine gets it in `hello` and
/// never writes it anywhere.
enum SyncKey {
    private static let service = "com.shivarajbakale.parley.mac"
    private static let account = "sync-token-key"

    static func loadOrCreate() -> Data? {
        if let existing = load() { return existing }
        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard status == errSecSuccess else { return nil }
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: bytes,
        ]
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? bytes : nil
    }

    private static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, data.count == 32
        else { return nil }
        return data
    }
}

/// Reads an agent's question aloud: the arrival cue for an approval.
@MainActor
enum Speech {
    private static let synthesizer = AVSpeechSynthesizer()

    static func say(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(AVSpeechUtterance(string: text))
    }
}

/// Launch at login through the system's login-item service. Only an app in
/// /Applications registers: a build in DerivedData would register a path
/// that disappears on the next clean.
enum LoginItem {
    private static let log = Logger(subsystem: "com.shivarajbakale.parley.mac", category: "login")

    static func set(_ enabled: Bool) {
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else {
            log.info("launch at login \(enabled) skipped: not installed in /Applications")
            return
        }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("launch at login failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
