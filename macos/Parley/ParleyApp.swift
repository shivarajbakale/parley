import ParleyCore
import SwiftUI

@main
struct ParleyApp: App {
    @State private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: controller)
        } label: {
            // The mark: tap, tap, hold. A template image, so macOS tints it.
            Image("MenuBarIcon")
                .task { controller.launch() }
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The menu: status, the four gestures, the last dictation, settings, quit.
struct MenuContent: View {
    let controller: AppController

    var body: some View {
        Text(statusLine)
        if !controller.permissions.microphone {
            Button("Allow Microphone…") { controller.requestMicrophone() }
        }
        if !controller.permissions.accessibility {
            if controller.accessibilityLooksStale {
                Text("Parley Native is on in System Settings but macOS still says no.")
                Text("Remove it with −, then add it again.")
                Button("Open Accessibility Settings…") { controller.openAccessibilitySettings() }
                Button("Show Parley Native in Finder") { controller.revealAppInFinder() }
            } else {
                Button("Allow Accessibility…") { controller.requestAccessibility() }
            }
        }
        if let view = controller.settings {
            Divider()
            Section("Tap, hold the last (×\(view.tapCount))") {
                gesture("Dictate", view.gestureKey, on: true)
                gesture("Voice edit", view.editGestureKey, on: view.editGestureKey != view.gestureKey)
                gesture("Explain", view.explainGestureKey,
                        on: ![view.gestureKey, view.editGestureKey].contains(view.explainGestureKey))
                gesture("Act", view.actGestureKey,
                        on: ![view.gestureKey, view.editGestureKey, view.explainGestureKey].contains(view.actGestureKey))
            }
        }
        if let last = controller.lastTranscript {
            Divider()
            Button("Copy last: \(last.prefix(40))\(last.count > 40 ? "…" : "")") {
                controller.copyLastTranscript()
            }
        }
        Divider()
        Button("Settings…") { controller.openSettings() }
            .keyboardShortcut(",")
        Button("Quit Parley") { controller.quit() }
            .keyboardShortcut("q")
    }

    private func gesture(_ title: String, _ key: GestureKeyName, on: Bool) -> some View {
        Text(on ? "\(title) — \(key.short)" : "\(title) — off")
    }

    private var statusLine: String {
        switch controller.status {
        case .starting: "Parley · starting…"
        case .ready: "Parley · ready"
        case .needsPermission: "Parley · needs permission"
        case .blocked(let reason): reason
        }
    }
}
