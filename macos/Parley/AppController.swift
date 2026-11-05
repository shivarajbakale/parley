import AppKit
import os
import ParleyCore

/// Wires the shell together: engine process ↔ RPC peer, key tap → engine,
/// engine's HUD phases → pill and recorder, engine's paste requests → paster.
@MainActor
@Observable
final class AppController {
    enum Status: Equatable {
        case starting
        case ready
        case needsPermission
        case blocked(String)
    }

    private(set) var status: Status = .starting
    private(set) var permissions = PermissionState.current()
    private(set) var engineVersion: String?
    /// The dictation gesture as the engine's settings have it, e.g. "Right ⌥ ×3".
    private(set) var gestureLabel: String?
    private(set) var lastTranscript: String?
    /// Accessibility was asked for, switched on in System Settings by the
    /// user, and macOS still says no: the list entry is stale (the build's
    /// signature changed). The menu says how to fix it.
    private(set) var accessibilityLooksStale = false

    @ObservationIgnored private let log = Logger(subsystem: "com.shivarajbakale.parley.mac", category: "app")
    @ObservationIgnored private let engine = EngineProcess()
    @ObservationIgnored private let keyTap = KeyTap()
    @ObservationIgnored private let audio = AudioCapture()
    @ObservationIgnored private let hud = HUDPanel()
    @ObservationIgnored private lazy var paster = Paster(sendPaste: { Self.sendCommandV() })
    @ObservationIgnored private var peer: RPCPeer?
    @ObservationIgnored private var exits: [Date] = []
    @ObservationIgnored private var permissionTimer: Timer?
    @ObservationIgnored private var accessibilityAskedAt: Date?
    /// Past this, a request that still reads as untrusted is probably stale.
    private static let staleAfter: TimeInterval = 20

    /// Electron's packaged id, and the dev binary when run from this repo.
    private static let electronBundleIds: Set<String> = ["parley", "com.github.Electron"]

    func launch() {
        // A write to a dead engine's pipe must fail, not kill the shell.
        signal(SIGPIPE, SIG_IGN)
        if let running = conflictingElectronBuild() {
            status = .blocked("Quit the Electron Parley first (\(running)). Both would answer the same keys.")
            return
        }
        keyTap.onTransition = { [weak self] transition, time in
            self?.peer?.notify("key", ["type": .string(transition.kind.rawValue), "key": .string(transition.key), "time": .number(time)])
        }
        audio.onLevel = { [weak self] level in self?.hud.model.push(level: level) }
        startEngine()
        startKeyTapIfTrusted()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPermissions() }
        }
    }

    func quit() {
        engine.stop()
        NSApp.terminate(nil)
    }

    func copyLastTranscript() {
        guard let lastTranscript else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
    }

    func requestMicrophone() {
        Task { _ = await Permissions.requestMicrophone(); pollPermissions() }
    }

    func requestAccessibility() {
        // A gesture refused for Accessibility arrives on every attempt; one
        // trip to System Settings a minute is plenty.
        if let asked = accessibilityAskedAt, Date().timeIntervalSince(asked) < 60 { return }
        accessibilityAskedAt = Date()
        Permissions.requestAccessibility()
    }

    func openAccessibilitySettings() {
        accessibilityAskedAt = Date()
        Permissions.openSettings(anchor: "Privacy_Accessibility")
    }

    func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    // MARK: - Engine

    private func startEngine() {
        let peer = RPCPeer(
            write: { [weak self] line in self?.engine.send(line) },
            onRequest: { [weak self] method, params in
                guard let self else { throw RPCError(code: RPCError.handlerFailed, message: "shell gone") }
                return try await self.handleRequest(method, params)
            },
            onNotify: { [weak self] method, params in self?.handleNotify(method, params) },
            onProtocolError: { [weak self] message in self?.log.warning("rpc: \(message, privacy: .public)") }
        )
        self.peer = peer
        engine.onLine = { [weak peer] line in peer?.receive(line) }
        engine.onExit = { [weak self] code in self?.engineExited(code) }
        do {
            try engine.start()
        } catch {
            status = .blocked(error.localizedDescription)
            return
        }
        Task { await hello() }
    }

    private func hello() async {
        guard let peer else { return }
        do {
            let reply = try await peer.request("hello", [
                "protocolVersion": .number(Double(ParleyCore.protocolVersion)),
                "appVersion": .string(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"),
                "permissions": permissionsJSON,
            ])
            engineVersion = reply["engineVersion"]?.string
            log.info("hello ok, engine \(self.engineVersion ?? "?", privacy: .public), mic \(self.permissions.microphone), ax \(self.permissions.accessibility)")
            if let key = reply["settings"]?["gestureKey"]?.string,
               let taps = reply["settings"]?["tapCount"]?.number {
                gestureLabel = "\(Self.keyLabel(key)) ×\(Int(taps))"
            }
            refreshStatus()
        } catch {
            status = .blocked("The engine would not start: \(error.localizedDescription)")
        }
    }

    private func engineExited(_ code: Int32) {
        peer?.close(reason: "engine exited")
        if audio.isRecording { audio.discard() }
        hud.hide()
        log.error("engine exited with \(code)")
        let now = Date()
        exits = exits.filter { now.timeIntervalSince($0) < 60 } + [now]
        guard exits.count < 3 else {
            status = .blocked("The engine stopped three times in a minute. See Console for the log.")
            return
        }
        status = .starting
        let delay = Double(exits.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated { self?.startEngine() }
        }
    }

    private func handleRequest(_ method: String, _ params: JSONValue?) async throws -> JSONValue {
        switch method {
        case "paste.text":
            guard let text = params?["text"]?.string else {
                throw RPCError(code: RPCError.handlerFailed, message: "paste.text without text")
            }
            guard AXIsProcessTrusted() else {
                throw RPCError(code: RPCError.handlerFailed, message: "Parley needs Accessibility to paste")
            }
            await paster.paste(text)
            log.info("pasted \(text.count) chars")
            return ["ok": true]
        default:
            throw RPCError(code: RPCError.methodNotFound, message: "Unknown method \(method)")
        }
    }

    private func handleNotify(_ method: String, _ params: JSONValue?) {
        switch method {
        case "hud.show":
            hud.show()
        case "hud.hide":
            hud.hide()
        case "hud.phase":
            guard let phase = HUDPhase(params) else { return }
            apply(phase)
        case "transcript":
            lastTranscript = params?["text"]?.string
        case "session.blocked":
            switch params?["reason"]?.string {
            case "microphone": requestMicrophone()
            case "accessibility": requestAccessibility()
            default: break
            }
        case "ui.openSettings":
            refreshStatus()
        case "log":
            log.info("engine: \(params?["message"]?.string ?? "", privacy: .public)")
        default:
            log.debug("ignored \(method, privacy: .public)")
        }
    }

    private func apply(_ phase: HUDPhase) {
        log.info("phase \(phase.phase.rawValue, privacy: .public) \(phase.message ?? "", privacy: .public)")
        hud.model.phase = phase.phase
        hud.model.message = phase.message
        if phase.tick { playTick(for: phase.phase) }
        switch recorderAction(for: phase.phase, isRecording: audio.isRecording) {
        case .start:
            do {
                try audio.start()
            } catch {
                log.error("recording failed: \(error.localizedDescription, privacy: .public)")
            }
        case .stopAndSend:
            log.info("take: \(self.audio.isRecording ? "recording" : "nothing recorded", privacy: .public)")
            // Always answered: the engine's session waits on exactly one.
            if let take = audio.stop() {
                peer?.notify("audio.ready", [
                    "path": .string(take.url.path),
                    "mimeType": "audio/mp4",
                    "durationMs": .number(take.durationMs),
                ])
            } else {
                peer?.notify("audio.ready", ["path": "", "mimeType": "audio/mp4", "durationMs": 0])
            }
        case .discard:
            audio.discard()
        case .none:
            break
        }
    }

    private func playTick(for phase: HUDPhase.Phase) {
        let name: NSSound.Name? = switch phase {
        case .listening: "Tink"
        case .transcribing: "Pop"
        default: nil
        }
        if let name, let sound = NSSound(named: name) {
            sound.volume = 0.25
            sound.play()
        }
    }

    // MARK: - Permissions and keys

    private var permissionsJSON: JSONValue {
        ["microphone": .bool(permissions.microphone), "accessibility": .bool(permissions.accessibility)]
    }

    private func pollPermissions() {
        let now = PermissionState.current()
        if !now.accessibility, let asked = accessibilityAskedAt {
            accessibilityLooksStale = Date().timeIntervalSince(asked) > Self.staleAfter
        }
        guard now != permissions else { return }
        let justTrusted = now.accessibility && !permissions.accessibility
        permissions = now
        peer?.notify("permissions.changed", permissionsJSON)
        startKeyTapIfTrusted()
        log.info("permissions mic \(now.microphone) ax \(now.accessibility), tap \(self.keyTap.isRunning)")
        refreshStatus()
        if justTrusted {
            accessibilityAskedAt = nil
            accessibilityLooksStale = false
            if status == .ready { announce("Parley is ready. \(gestureLabel ?? "Your gesture"), hold the last.") }
        } else if now.microphone && !now.accessibility {
            // Microphone just landed: go straight on to the other one.
            requestAccessibility()
        }
    }

    /// A short pill outside any session, e.g. "ready".
    private func announce(_ message: String) {
        hud.show()
        hud.model.phase = .notice
        hud.model.message = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.hud.model.phase == .notice else { return }
                self.hud.hide()
            }
        }
    }

    private func startKeyTapIfTrusted() {
        guard permissions.accessibility, !keyTap.isRunning else { return }
        if !keyTap.start() {
            log.warning("key tap refused; asking for Input Monitoring")
            CGRequestListenEventAccess()
        }
    }

    private func refreshStatus() {
        if case .blocked = status { return }
        guard engineVersion != nil else { return }
        status = permissions.microphone && permissions.accessibility && keyTap.isRunning ? .ready : .needsPermission
    }

    private func conflictingElectronBuild() -> String? {
        let ownPid = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.first { app in
            guard app.processIdentifier != ownPid, let id = app.bundleIdentifier else { return false }
            if id == "parley" { return true }
            // The dev build runs as plain Electron from this repo's node_modules.
            return id == "com.github.Electron" && (app.executableURL?.path.contains("/parley/") ?? false)
        }?.localizedName
    }

    private static func keyLabel(_ key: String) -> String {
        let side = key.hasSuffix("Right") ? "Right" : "Left"
        let symbol = switch key.replacingOccurrences(of: "Right", with: "") {
        case "Alt": "⌥"
        case "Ctrl": "⌃"
        case "Shift": "⇧"
        case "Meta": "⌘"
        default: key
        }
        return "\(side) \(symbol)"
    }

    /// ⌘V as a synthetic keystroke; needs Accessibility.
    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
