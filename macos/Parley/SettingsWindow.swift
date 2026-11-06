import AppKit
import ParleyCore
import SwiftUI

/// Settings state and actions. Every change goes to the engine, which owns
/// the settings file; the window only shows what the engine sends back.
@MainActor
@Observable
final class SettingsModel {
    var view: SettingsView?
    var entries: [DictionaryEntry] = []
    var server: ServerStatus?
    var permissions = PermissionState(microphone: false, accessibility: false)
    var notice: String?
    var busy = false

    @ObservationIgnored var call: (String, JSONValue?) async throws -> JSONValue = { _, _ in .null }
    @ObservationIgnored var requestMicrophone: () -> Void = {}
    @ObservationIgnored var requestAccessibility: () -> Void = {}

    func refresh() async {
        await run {
            self.view = JSONBridge.decode(SettingsView.self, from: try await self.call("settings.get", nil))
            self.entries = JSONBridge.decode([DictionaryEntry].self, from: try await self.call("dictionary.list", nil)["entries"]) ?? []
        }
        await refreshServer()
    }

    func refreshServer() async {
        server = JSONBridge.decode(ServerStatus.self, from: try? await call("server.status", nil))
    }

    func update(_ patch: JSONValue) {
        Task {
            await run { self.apply(try await self.call("settings.update", ["patch": patch])) }
        }
    }

    func setProvider(_ provider: String) {
        Task { await run { self.apply(try await self.call("settings.setProvider", ["provider": .string(provider)])) } }
    }

    func addWord(_ word: String, heardAs: String) {
        let sounds = heardAs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        Task {
            await run {
                _ = try await self.call("dictionary.upsert", [
                    "word": .string(word.trimmingCharacters(in: .whitespaces)),
                    "soundsLike": .array(sounds.map { .string($0) }),
                ])
                self.entries = JSONBridge.decode([DictionaryEntry].self, from: try await self.call("dictionary.list", nil)["entries"]) ?? []
            }
        }
    }

    func remove(_ entry: DictionaryEntry) {
        Task {
            await run {
                self.entries = JSONBridge.decode([DictionaryEntry].self, from: try await self.call("dictionary.remove", ["id": .string(entry.id)])["entries"]) ?? []
            }
        }
    }

    func agent(_ method: String, _ params: JSONValue? = nil) {
        Task {
            await run {
                let reply = try await self.call(method, params)
                if let message = reply["message"]?.string { self.notice = message }
                self.apply(try await self.call("settings.get", nil))
            }
        }
    }

    /// The key goes to the server and is not kept here, not even in this model.
    func setKey(_ provider: String, _ key: String) async -> Bool {
        var saved = false
        await run {
            self.server = JSONBridge.decode(ServerStatus.self, from: try await self.call(
                "server.setKey", ["provider": .string(provider), "key": .string(key)]))
            self.notice = "Key saved on the Parley server"
            saved = true
        }
        return saved
    }

    func removeKey(_ provider: String) {
        Task {
            await run {
                self.server = JSONBridge.decode(ServerStatus.self, from: try await self.call(
                    "server.removeKey", ["provider": .string(provider)]))
                self.notice = "Key removed"
            }
        }
    }

    func signIn(_ email: String) {
        Task {
            await run {
                let reply = try await self.call("sync.signIn", ["email": .string(email)])
                self.notice = reply["message"]?.string
                self.apply(try await self.call("settings.get", nil))
            }
        }
    }

    func signOut() {
        Task { await run { self.apply(try await self.call("sync.signOut", nil)) } }
    }

    func syncNow() {
        Task {
            await run {
                let outcome = try await self.call("sync.now", nil)
                self.notice = outcome["ok"]?.bool == true ? "Synced" : (outcome["message"]?.string ?? "Sync failed")
                self.apply(try await self.call("settings.get", nil))
            }
        }
    }

    func apply(_ value: JSONValue) {
        if let decoded = JSONBridge.decode(SettingsView.self, from: value) { view = decoded }
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        busy = true
        defer { busy = false }
        do {
            try await work()
        } catch {
            notice = error.localizedDescription
        }
    }
}

/// Owns the settings window. A plain NSWindow hosting SwiftUI, so a menu-bar
/// app with no dock icon can bring it to the front on demand.
@MainActor
final class SettingsWindowController {
    let model = SettingsModel()
    private var window: NSWindow?

    func show(section: SettingsSection? = nil) {
        if let section { model.selection = section }
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsRoot(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Parley"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 860, height: 600))
            window.minSize = NSSize(width: 720, height: 480)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        Task { await model.refresh() }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general, keys, dictionary, agent, server
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .keys: "Keys & gestures"
        case .dictionary: "Dictionary"
        case .agent: "Agent"
        case .server: "Server & sync"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .keys: "keyboard"
        case .dictionary: "character.book.closed"
        case .agent: "sparkles"
        case .server: "arrow.triangle.2.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .keys: .orange
        case .dictionary: .teal
        case .agent: .purple
        case .server: .green
        }
    }
}

extension SettingsModel {
    var selection: SettingsSection {
        get { SettingsSelection.shared.value }
        set { SettingsSelection.shared.value = newValue }
    }
}

@MainActor
@Observable
final class SettingsSelection {
    static let shared = SettingsSelection()
    var value: SettingsSection = .general
}

struct SettingsRoot: View {
    @Bindable var model: SettingsModel
    @Bindable var selection = SettingsSelection.shared

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: Binding($selection.value)) { section in
                Label {
                    Text(section.title)
                } icon: {
                    Image(systemName: section.symbol)
                        .foregroundStyle(.white)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(section.tint.gradient, in: .rect(cornerRadius: 6))
                }
                .tag(section)
            }
            .navigationSplitViewColumnWidth(220)
        } detail: {
            Group {
                if let view = model.view {
                    switch selection.value {
                    case .general: GeneralPane(model: model, view: view)
                    case .keys: KeysPane(model: model, view: view)
                    case .dictionary: DictionaryPane(model: model)
                    case .agent: AgentPane(model: model, view: view)
                    case .server: ServerPane(model: model, view: view)
                    }
                } else {
                    ProgressView("Talking to the engine…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(selection.value.title)
        }
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                Text(notice)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 16)
                    .task(id: notice) {
                        try? await Task.sleep(for: .seconds(3))
                        if model.notice == notice { model.notice = nil }
                    }
            }
        }
    }
}

private struct GeneralPane: View {
    let model: SettingsModel
    let view: SettingsView

    var body: some View {
        Form {
            Section {
                LabeledContent("Parley server") {
                    StatusDot(ok: model.server?.reachable == true,
                              text: model.server?.reachable == true ? "Connected" : "Not reachable")
                }
                LabeledContent("Words dictated", value: view.wordsDictated.formatted())
            }
            Section("Dictation") {
                Picker("Transcription", selection: Binding(
                    get: { view.transcriptionProvider },
                    set: { model.setProvider($0) }
                )) {
                    Text("Groq Whisper").tag("groq")
                    Text("Deepgram Nova").tag("deepgram")
                }
                VocabularyField(model: model, saved: view.vocabulary)
                Toggle("Sounds when recording starts and stops", isOn: Binding(
                    get: { view.tickSound },
                    set: { model.update(["tickSound": .bool($0)]) }
                ))
            }
            Section("Behaviour") {
                Toggle(isOn: Binding(get: { view.launchAtLogin }, set: { model.update(["launchAtLogin": .bool($0)]) })) {
                    Text("Launch at login")
                    Text("Parley starts in the menu bar.")
                }
            }
            Section("Permissions") {
                PermissionRow(title: "Microphone", detail: "Only while a key is held",
                              granted: model.permissions.microphone, request: model.requestMicrophone)
                PermissionRow(title: "Accessibility", detail: "Reads the field, pastes at the cursor",
                              granted: model.permissions.accessibility, request: model.requestAccessibility)
            }
        }
        .formStyle(.grouped)
    }
}

/// Saved on Return or when focus leaves, not on every keystroke.
private struct VocabularyField: View {
    let model: SettingsModel
    let saved: String
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Vocabulary", text: $text, prompt: Text("Names and terms, comma separated"))
            .focused($focused)
            .onAppear { text = saved }
            .onSubmit(save)
            .onChange(of: focused) { _, isFocused in if !isFocused { save() } }
    }

    private func save() {
        if text != saved { model.update(["vocabulary": .string(text)]) }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let request: () -> Void

    var body: some View {
        LabeledContent {
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Allow…", action: request).buttonStyle(.borderedProminent)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}

private struct StatusDot: View {
    let ok: Bool
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(ok ? Color.green : Color.orange).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

private struct KeysPane: View {
    let model: SettingsModel
    let view: SettingsView

    var body: some View {
        Form {
            Section {
                keyRow("Dictate", "Types what you say", "gestureKey", view.gestureKey)
                keyRow("Voice edit", "Rewrites the selection or field", "editGestureKey", view.editGestureKey)
                keyRow("Explain", "Answers about the selection", "explainGestureKey", view.explainGestureKey)
                keyRow("Act", "Hands the command to the agent", "actGestureKey", view.actGestureKey)
            } header: {
                Text("Modes")
            } footer: {
                Text("Tap the key twice, then hold it while you speak. Click a key and press a modifier to change it; a key another mode uses is swapped with it.")
            }
        }
        .formStyle(.grouped)
    }

    @State private var recording: String?
    @State private var swapped: (field: String, with: String)?

    private var current: [String: GestureKeyName] {
        ["gestureKey": view.gestureKey, "editGestureKey": view.editGestureKey,
         "explainGestureKey": view.explainGestureKey, "actGestureKey": view.actGestureKey]
    }

    private static let titles = ["gestureKey": "Dictate", "editGestureKey": "Voice edit",
                                 "explainGestureKey": "Explain", "actGestureKey": "Act"]

    private func keyRow(_ title: String, _ detail: String, _ field: String, _ value: GestureKeyName) -> some View {
        let duplicate = ModeKeys.fields.prefix { $0 != field }.contains { current[$0] == value }
        return LabeledContent {
            KeyRecorder(key: value, recording: Binding(
                get: { recording == field },
                set: { recording = $0 ? field : nil }
            )) { key in assign(key, to: field) }
        } label: {
            Text(title)
            if duplicate {
                Text("Off: same key as another mode. Record a new one.").foregroundStyle(.orange)
            } else if let swapped, swapped.field == field {
                Text("Swapped with \(swapped.with)").foregroundStyle(.secondary)
            } else {
                Text(detail)
            }
        }
    }

    private func assign(_ key: GestureKeyName, to field: String) {
        let patch = ModeKeys.assign(key, to: field, current: current)
        guard !patch.isEmpty else { return }
        model.update(.object(patch.mapValues { .string($0.rawValue) }))
        if let other = patch.keys.first(where: { $0 != field }) {
            swapped = (field, Self.titles[other] ?? "another mode")
            Task {
                try? await Task.sleep(for: .seconds(3))
                if swapped?.field == field { swapped = nil }
            }
        } else {
            swapped = nil
        }
    }
}

/// A Raycast-style shortcut field: shows the key as a keycap; click it and
/// press a modifier to change it. Esc or a click elsewhere cancels. Only
/// modifiers count: a gesture is taps of one modifier key.
private struct KeyRecorder: View {
    let key: GestureKeyName
    @Binding var recording: Bool
    let onRecord: (GestureKeyName) -> Void
    @State private var monitor: Any?

    var body: some View {
        Button { recording.toggle() } label: {
            HStack(spacing: 6) {
                if recording {
                    Text("Press a modifier…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    // Tap, tap, hold: the gesture drawn as three presses.
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { press in
                            Text(key.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(minWidth: press == 2 ? 34 : 22, minHeight: 20)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    Text(key.name)
                }
            }
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: 210)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(recording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(recording ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: recording ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.15), value: recording)
        .onChange(of: recording) { _, on in on ? start() : stop() }
        .onDisappear { recording = false; stop() }
        .help("Click, then press a modifier key")
    }

    private func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .leftMouseDown]) { event in
            switch event.type {
            case .flagsChanged:
                // A press, not the release: the key's own flag is now set.
                if let pressed = GestureKeyName(keyCode: event.keyCode),
                   event.modifierFlags.contains(Self.flag(for: pressed)) {
                    onRecord(pressed)
                    recording = false
                }
                return nil
            case .keyDown:
                recording = false // Esc, or any non-modifier: cancel
                return nil
            default:
                recording = false // a click elsewhere cancels; let it through
                return event
            }
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private static func flag(for key: GestureKeyName) -> NSEvent.ModifierFlags {
        switch key {
        case .AltRight, .Alt: .option
        case .CtrlRight, .Ctrl: .control
        case .ShiftRight, .Shift: .shift
        case .MetaRight, .Meta: .command
        }
    }
}

private struct DictionaryPane: View {
    let model: SettingsModel
    @State private var search = ""
    @State private var newWord = ""
    @State private var heardAs = ""

    private var shown: [DictionaryEntry] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let all = model.entries.sorted { $0.word.lowercased() < $1.word.lowercased() }
        guard !query.isEmpty else { return all }
        return all.filter { $0.word.lowercased().contains(query) || $0.soundsLike.joined(separator: " ").lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Names and jargon, spelled your way. Parley also offers to learn a word when you fix it right after dictating.")
                .foregroundStyle(.secondary)
            HStack {
                TextField("Word", text: $newWord, prompt: Text("Mastra"))
                TextField("Heard as", text: $heardAs, prompt: Text("master, mast ra"))
                Button("Add") {
                    model.addWord(newWord, heardAs: heardAs)
                    newWord = ""
                    heardAs = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Table(shown) {
                TableColumn("Written as") { entry in Text(entry.word).fontWeight(.semibold) }
                TableColumn("Heard as") { entry in Text(entry.soundsLike.joined(separator: ", ")).foregroundStyle(.secondary) }
                TableColumn("Uses") { entry in Text("\(entry.uses ?? 0)").monospacedDigit() }
                    .width(60)
                TableColumn("") { entry in
                    Button(role: .destructive) { model.remove(entry) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(entry.word)")
                }
                .width(36)
            }
            .overlay {
                if shown.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "No words yet" : "No matches",
                                           systemImage: "character.book.closed",
                                           description: Text(search.isEmpty ? "Add a name Parley keeps getting wrong." : "Try another spelling."))
                }
            }
        }
        .padding(20)
        .searchable(text: $search, placement: .toolbar)
    }
}

private struct AgentPane: View {
    let model: SettingsModel
    let view: SettingsView
    @State private var url = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    StatusDot(ok: view.agent.online, text: view.agent.online ? "Online" : view.agent.serverState.capitalized)
                }
                if !view.agent.message.isEmpty {
                    Text(view.agent.message).foregroundStyle(.secondary)
                }
                if let run = view.agent.currentRun {
                    LabeledContent(run.status == "awaiting_approval" ? "Waiting for you" : "Working", value: run.summary)
                    if let callId = run.callId {
                        HStack {
                            Button("Approve") { model.agent("agent.decide", ["callId": .string(callId), "approved": true]) }
                                .buttonStyle(.borderedProminent)
                            Button("Decline") { model.agent("agent.decide", ["callId": .string(callId), "approved": false]) }
                        }
                    }
                }
            }
            Section("Tools") {
                if view.agent.mcpServers.isEmpty {
                    Text("No MCP servers connected.").foregroundStyle(.secondary)
                }
                ForEach(view.agent.mcpServers) { server in
                    LabeledContent(server.name, value: "\(server.tools) tools")
                }
            }
            Section("Server") {
                TextField("Agent URL", text: $url, prompt: Text("http://localhost:4111"))
                    .onAppear { url = view.agentUrl }
                    .onSubmit { model.agent("agent.setUrl", ["url": .string(url)]) }
                Toggle(isOn: Binding(get: { view.agentAutoStart }, set: { model.update(["agentAutoStart": .bool($0)]) })) {
                    Text("Start the agent with Parley")
                    Text("Off attaches to a server you run yourself.")
                }
                HStack {
                    Button("Save URL") { model.agent("agent.setUrl", ["url": .string(url)]) }
                    Button("Test") { model.agent("agent.test") }
                    Button("Restart") { model.agent("agent.restart") }.disabled(!view.agent.managed)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ProviderKey: Identifiable {
    let id: String
    let name: String
    let purpose: String
    let console: URL

    static let all = [
        ProviderKey(id: "groq", name: "Groq", purpose: "Transcription (Whisper)",
                    console: URL(string: "https://console.groq.com/keys")!),
        ProviderKey(id: "deepgram", name: "Deepgram", purpose: "Transcription (Nova), optional",
                    console: URL(string: "https://console.deepgram.com")!),
        ProviderKey(id: "minimax", name: "MiniMax", purpose: "Voice edit, Explain and Act",
                    console: URL(string: "https://www.minimax.io/platform")!),
        ProviderKey(id: "exa", name: "Exa", purpose: "Web search for Explain and Act",
                    console: URL(string: "https://dashboard.exa.ai/api-keys")!),
    ]
}

private struct ProviderKeyRow: View {
    let model: SettingsModel
    let provider: ProviderKey
    /// nil while the server has not answered.
    let isSet: Bool?
    let inUse: Bool
    @State private var editing = false
    @State private var key = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent {
                HStack(spacing: 10) {
                    switch isSet {
                    case true?: Label("Set", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case false?: Label(inUse ? "Missing — in use" : "Not set", systemImage: inUse ? "exclamationmark.triangle.fill" : "circle")
                        .foregroundStyle(inUse ? .orange : .secondary)
                    case nil: Text("—").foregroundStyle(.secondary)
                    }
                    Button(isSet == true ? "Replace…" : "Add…") { editing.toggle() }
                    if isSet == true {
                        Button("Remove", role: .destructive) { model.removeKey(provider.id) }
                    }
                }
            } label: {
                Text(provider.name)
                Text(provider.purpose)
            }
            if editing {
                HStack {
                    SecureField("Paste the \(provider.name) key", text: $key)
                        .onSubmit(save)
                    Link("Get a key", destination: provider.console)
                    Button("Save", action: save)
                        .buttonStyle(.borderedProminent)
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let value = key
        // Cleared at once: the key does not linger in the view.
        key = ""
        Task {
            if await model.setKey(provider.id, value) { editing = false }
        }
    }
}

private struct ServerPane: View {
    let model: SettingsModel
    let view: SettingsView
    @State private var serverUrl = ""
    @State private var email = ""

    var body: some View {
        Form {
            Section {
                TextField("Server address", text: $serverUrl, prompt: Text("http://localhost:3100"))
                    .onAppear { serverUrl = view.syncUrl }
                    .onSubmit(save)
                LabeledContent("Status") {
                    StatusDot(ok: model.server?.reachable == true,
                              text: model.server?.reachable == true ? "Connected" : "Not reachable")
                }
                Button("Save and check", action: save)
            } header: {
                Text("Parley server")
            } footer: {
                Text("Transcription, voice edit, Explain and sync go through this server; it holds the provider keys.")
            }
            Section {
                ForEach(ProviderKey.all) { provider in
                    ProviderKeyRow(model: model, provider: provider,
                                   isSet: model.server?.keys?.has(provider.id),
                                   inUse: provider.id == view.transcriptionProvider)
                }
            } header: {
                Text("Provider keys")
            } footer: {
                Text("Keys are sent to your Parley server and kept there — never on this Mac. Paste a new key to replace one.")
            }
            Section("Sync") {
                if view.hasSyncToken {
                    LabeledContent("Account", value: view.syncEmail)
                    Toggle("Sync this Mac", isOn: Binding(get: { view.syncEnabled }, set: { model.update(["syncEnabled": .bool($0)]) }))
                    LabeledContent("Last sync", value: view.syncLastAt > 0
                        ? Date(timeIntervalSince1970: view.syncLastAt / 1000).formatted(.relative(presentation: .named))
                        : "Never")
                    if !view.syncLastError.isEmpty {
                        Text(view.syncLastError).foregroundStyle(.red)
                    }
                    HStack {
                        Button("Sync now", action: model.syncNow)
                        Button("Sign out", role: .destructive, action: model.signOut)
                    }
                } else {
                    TextField("Email", text: $email, prompt: Text("you@example.com"))
                        .onSubmit { model.signIn(email) }
                    Button("Sign in") { model.signIn(email) }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func save() {
        model.update(["syncUrl": .string(serverUrl.trimmingCharacters(in: .whitespaces))])
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await model.refreshServer()
        }
    }
}
