import SwiftUI

@main
struct ParleyApp: App {
    @State private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: controller)
        } label: {
            Image(systemName: "waveform")
                .task { controller.launch() }
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Phase 1 menu: status, permissions, the last dictation, quit. The glass
/// panel from the design canvas replaces it in phase 3.
struct MenuContent: View {
    let controller: AppController

    var body: some View {
        Text(statusLine)
        if let version = controller.engineVersion {
            Text("Engine \(version) · Dictate: \(controller.gestureLabel ?? "…"), hold the last").font(.caption)
        }
        Divider()
        if !controller.permissions.microphone {
            Button("Allow Microphone…") { controller.requestMicrophone() }
        }
        if !controller.permissions.accessibility {
            Button("Allow Accessibility…") { controller.requestAccessibility() }
        }
        if let last = controller.lastTranscript {
            Button("Copy last: \(last.prefix(40))\(last.count > 40 ? "…" : "")") {
                controller.copyLastTranscript()
            }
        }
        Divider()
        Button("Quit Parley") { controller.quit() }
            .keyboardShortcut("q")
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
