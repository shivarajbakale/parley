import AppKit

/// The keystrokes Parley sends to the focused app.
public enum Keystroke: Sendable, Equatable {
    case paste, copy, selectAll, backspace
}

/// Everything Parley does through the pasteboard and synthetic keys: paste at
/// the caret (optionally over the whole field), copy the whole field or the
/// selection, and erase typed input in a terminal. The user's clipboard is
/// put back after every operation that touches it. Timings match the engine's
/// `injector.ts`, where they were tuned against real apps.
@MainActor
public final class Paster {
    public static let pasteSettle: Duration = .milliseconds(50)
    public static let restoreDelay: Duration = .milliseconds(200)
    public static let selectSettle: Duration = .milliseconds(50)
    public static let copySettle: Duration = .milliseconds(150)
    public static let eraseBatch = 50
    public static let eraseSettle: Duration = .milliseconds(20)

    private let pasteboard: NSPasteboard
    private let send: @MainActor (Keystroke) -> Void
    private let sleep: @MainActor (Duration) async -> Void

    public init(
        pasteboard: NSPasteboard = .general,
        send: @escaping @MainActor (Keystroke) -> Void,
        sleep: @escaping @MainActor (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.pasteboard = pasteboard
        self.send = send
        self.sleep = sleep
    }

    /// `selectAll` replaces the whole focused field instead of the selection.
    public func paste(_ text: String, selectAll: Bool = false) async {
        let saved = snapshot()
        write(text)
        await sleep(Self.pasteSettle)
        if selectAll {
            send(.selectAll)
            await sleep(Self.selectSettle)
        }
        send(.paste)
        await sleep(Self.restoreDelay)
        restore(saved)
    }

    /// Select everything in the focused field and return it. Only safe once
    /// the focus is known to be a text field.
    public func copyAll() async -> String {
        let saved = snapshot()
        // Emptied first, so a ⌘C that copies nothing reads back as nothing.
        write("")
        send(.selectAll)
        await sleep(Self.selectSettle)
        send(.copy)
        await sleep(Self.copySettle)
        let text = pasteboard.string(forType: .string) ?? ""
        restore(saved)
        return text
    }

    /// Copy what is selected right now, without selecting anything.
    public func copySelection() async -> String {
        let saved = snapshot()
        write("")
        send(.copy)
        await sleep(Self.copySettle)
        let text = pasteboard.string(forType: .string) ?? ""
        restore(saved)
        return text
    }

    /// Backspace `count` times: how a terminal's typed input is cleared.
    public func erase(_ count: Int) async {
        guard count > 0 else { return }
        for sent in 0..<count {
            send(.backspace)
            if (sent + 1) % Self.eraseBatch == 0 { await sleep(Self.eraseSettle) }
        }
        await sleep(Self.eraseSettle)
    }

    /// A plain write the user asked for (an agent's long answer, Explain's copy).
    public func writeClipboard(_ text: String) {
        write(text)
    }

    private func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Every item, every type, as raw data: rich text, images and files
    /// survive the round trip, not just the plain string.
    func snapshot() -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var types: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { types[type] = data }
            }
            return types
        }
    }

    func restore(_ saved: [[NSPasteboard.PasteboardType: Data]]) {
        pasteboard.clearContents()
        guard !saved.isEmpty else { return }
        let items = saved.map { types -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in types { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(items)
    }
}
