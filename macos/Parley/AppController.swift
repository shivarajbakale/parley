import AppKit
import os
import ParleyCore

/// Wires the shell together: engine process ↔ RPC peer, key tap → engine,
/// and every OS service the engine asks for — the pill and recorder, paste
/// and copy, Accessibility reads, the Explain card, speech, the clipboard,
/// login items and the settings window.
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
    private(set) var settings: SettingsView?
    private(set) var lastTranscript: String?
    /// Accessibility was asked for, switched on in System Settings by the
    /// user, and macOS still says no: the list entry is stale (the build's
    /// signature changed). The menu says how to fix it.
    private(set) var accessibilityLooksStale = false

    /// "Right ⌥ ×3" for the menu, from the engine's settings.
    var gestureLabel: String? {
        settings.map { "\($0.gestureKey.short) ×\($0.tapCount)" }
    }

    @ObservationIgnored private let log = Logger(subsystem: "com.shivarajbakale.parley.mac", category: "app")
    @ObservationIgnored private let engine = EngineProcess()
    @ObservationIgnored private let keyTap = KeyTap()
    @ObservationIgnored private let audio = AudioCapture()
    @ObservationIgnored private let hud = HUDPanel()
    @ObservationIgnored private let explain = ExplainPanel()
    @ObservationIgnored let settingsWindow = SettingsWindowController()
    @ObservationIgnored private lazy var paster = Paster(send: { Self.send($0) })
    @ObservationIgnored private var peer: RPCPeer?
    @ObservationIgnored private var exits: [Date] = []
    @ObservationIgnored private var permissionTimer: Timer?
    @ObservationIgnored private var accessibilityAskedAt: Date?
    /// When the user (not Parley) last copied something, for Explain's
    /// "explain what I just copied" fallback.
    @ObservationIgnored private var lastSeenChangeCount = NSPasteboard.general.changeCount
    @ObservationIgnored private var lastUserCopyAt: Date?
    @ObservationIgnored private var clipboardTimer: Timer?
    /// Past this, a request that still reads as untrusted is probably stale.
    private static let staleAfter: TimeInterval = 20

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
        explain.onDismiss = { [weak self] in self?.peer?.notify("explain.dismiss") }
        explain.onCopy = { [weak self] text in self?.paster.writeClipboard(text) }
        let model = settingsWindow.model
        model.call = { [weak self] method, params in
            guard let peer = self?.peer else { throw RPCError(code: RPCError.handlerFailed, message: "The engine is not running") }
            return try await peer.request(method, params)
        }
        model.requestMicrophone = { [weak self] in self?.requestMicrophone() }
        model.requestAccessibility = { [weak self] in self?.openAccessibilitySettings() }
        model.permissions = permissions
        startEngine()
        startKeyTapIfTrusted()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPermissions() }
        }
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.watchClipboard() }
        }
    }

    /// Only the change count is read here, never the contents.
    private func watchClipboard() {
        let count = NSPasteboard.general.changeCount
        guard count != lastSeenChangeCount else { return }
        lastSeenChangeCount = count
        if count != paster.ownChangeCount { lastUserCopyAt = Date() }
    }

    func quit() {
        engine.stop()
        // The engine cancels a live agent run on stdin close; give it a beat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NSApp.terminate(nil) }
    }

    func openSettings() {
        settingsWindow.show()
    }

    func copyLastTranscript() {
        guard let lastTranscript else { return }
        paster.writeClipboard(lastTranscript)
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
        Permissions.requestAccessibility()
    }

    func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    // MARK: - Engine

    private func startEngine() {
        let peer = RPCPeer(
            timeout: .seconds(30),
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

    /// The bundled agent server, when this build carries one.
    private var agentDir: JSONValue {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("parley-agent"),
              FileManager.default.fileExists(atPath: dir.appendingPathComponent("index.mjs").path)
        else { return .null }
        return .string(dir.path)
    }

    private func hello() async {
        guard let peer else { return }
        do {
            var params: [String: JSONValue] = [
                "protocolVersion": .number(Double(ParleyCore.protocolVersion)),
                "appVersion": .string(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"),
                "permissions": permissionsJSON,
                "agentDir": agentDir,
            ]
            if let key = SyncKey.loadOrCreate() { params["secretKey"] = .string(key.base64EncodedString()) }
            let reply = try await peer.request("hello", .object(params))
            engineVersion = reply["engineVersion"]?.string
            settings = JSONBridge.decode(SettingsView.self, from: reply["settings"])
            log.info("hello ok, engine \(self.engineVersion ?? "?", privacy: .public), mic \(self.permissions.microphone), ax \(self.permissions.accessibility)")
            refreshStatus()
            // First run: the settings window doubles as onboarding.
            if !permissions.microphone || !permissions.accessibility {
                openSettings()
            }
        } catch {
            status = .blocked("The engine would not start: \(error.localizedDescription)")
        }
    }

    private func engineExited(_ code: Int32) {
        peer?.close(reason: "engine exited")
        if audio.isRecording { audio.discard() }
        hud.hide()
        explain.hide()
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

    private func requireAccessibility() throws {
        guard AXIsProcessTrusted() else {
            throw RPCError(code: RPCError.handlerFailed, message: "Parley needs Accessibility for this")
        }
    }

    private func handleRequest(_ method: String, _ params: JSONValue?) async throws -> JSONValue {
        switch method {
        case "paste.text":
            guard let text = params?["text"]?.string else {
                throw RPCError(code: RPCError.handlerFailed, message: "paste.text without text")
            }
            try requireAccessibility()
            await paster.paste(text, selectAll: params?["selectAll"]?.bool == true)
            log.info("pasted \(text.count) chars")
            return ["ok": true]
        case "inject.copyAll":
            try requireAccessibility()
            return ["text": .string(await paster.copyAll())]
        case "inject.copySelection":
            try requireAccessibility()
            let held = CGEventSource.flagsState(.combinedSessionState)
            let before = NSPasteboard.general.changeCount
            let text = await paster.copySelection()
            log.info("copySelection: modifiers held cmd=\(held.contains(.maskCommand)) ctrl=\(held.contains(.maskControl)) opt=\(held.contains(.maskAlternate)) shift=\(held.contains(.maskShift)); pasteboard changes \(NSPasteboard.general.changeCount - before); \(text.count) chars")
            return ["text": .string(text)]
        case "inject.erase":
            try requireAccessibility()
            await paster.erase(Int(params?["count"]?.number ?? 0))
            return ["ok": true]
        case "clipboard.recent":
            watchClipboard()
            let within = (params?["withinMs"]?.number ?? 30_000) / 1000
            guard let at = lastUserCopyAt, Date().timeIntervalSince(at) <= within else { return ["text": ""] }
            return ["text": .string(NSPasteboard.general.string(forType: .string) ?? "")]
        case "ax.focusedField":
            return await Task.detached(priority: .userInitiated) { Accessibility.focusedField() }.value
        case "ax.select":
            let location = Int(params?["location"]?.number ?? -1)
            let length = Int(params?["length"]?.number ?? -1)
            guard location >= 0, length >= 0 else { return ["selected": false] }
            let selected = await Task.detached(priority: .userInitiated) {
                Accessibility.select(location: location, length: length)
            }.value
            return ["selected": .bool(selected)]
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
        case "explain.show":
            let anchor = Self.rect(params?["anchor"])
            explain.show(anchor: anchor,
                         content: JSONBridge.decode(ExplainContent.self, from: params?["content"]) ?? .empty,
                         fromClipboard: params?["fromClipboard"]?.bool == true,
                         app: NSWorkspace.shared.frontmostApplication?.localizedName)
        case "explain.update":
            explain.update(JSONBridge.decode(ExplainContent.self, from: params?["content"]) ?? .empty)
        case "explain.hide":
            explain.hide()
        case "clipboard.write":
            if let text = params?["text"]?.string { paster.writeClipboard(text) }
        case "speak":
            if let text = params?["text"]?.string { Speech.say(text) }
        case "app.launchAtLogin":
            LoginItem.set(params?["enabled"]?.bool == true)
        case "settings.changed":
            if let view = JSONBridge.decode(SettingsView.self, from: params?["view"]) {
                settings = view
                settingsWindow.model.view = view
            }
        case "transcript":
            lastTranscript = params?["text"]?.string
        case "session.blocked":
            switch params?["reason"]?.string {
            case "microphone": requestMicrophone()
            case "accessibility": requestAccessibility()
            case "agent": settingsWindow.show(section: .agent)
            default: break
            }
        case "ui.openSettings":
            refreshStatus()
            if params?["reason"]?.string == "agent" { settingsWindow.show(section: .agent) }
        case "log":
            log.info("engine: \(params?["message"]?.string ?? "", privacy: .public)")
        default:
            log.debug("ignored \(method, privacy: .public)")
        }
    }

    private static func rect(_ value: JSONValue?) -> CGRect? {
        guard let x = value?["x"]?.number, let y = value?["y"]?.number,
              let width = value?["width"]?.number, let height = value?["height"]?.number
        else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func apply(_ phase: HUDPhase) {
        log.info("phase \(phase.phase.rawValue, privacy: .public) \(phase.message ?? "", privacy: .public)")
        hud.model.apply(phase)
        if phase.tick { playTick(for: phase.phase) }
        switch recorderAction(for: phase.phase, isRecording: audio.isRecording) {
        case .start:
            do {
                try audio.start()
            } catch {
                log.error("recording failed: \(error.localizedDescription, privacy: .public)")
            }
        case .stopAndSend:
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
        settingsWindow.model.permissions = now
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
        hud.model.apply(HUDPhase(phase: .notice, message: message, accepted: true))
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

    /// A synthetic keystroke into the focused app; needs Accessibility.
    private static func send(_ keystroke: Keystroke) {
        let (key, flags): (CGKeyCode, CGEventFlags) = switch keystroke {
        case .paste: (9, .maskCommand)
        case .copy: (8, .maskCommand)
        case .selectAll: (0, .maskCommand)
        case .backspace: (51, [])
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
