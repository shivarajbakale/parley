import AppKit

/// Pastes text at the caret the way the Electron injector did: save the
/// pasteboard, put the text on it, send ⌘V, then put the user's clipboard
/// back. Timings match `electron/injector.ts`.
@MainActor
public final class Paster {
    public static let pasteSettle: Duration = .milliseconds(50)
    public static let restoreDelay: Duration = .milliseconds(200)

    private let pasteboard: NSPasteboard
    private let sendPaste: @MainActor () -> Void
    private let sleep: @MainActor (Duration) async -> Void

    public init(
        pasteboard: NSPasteboard = .general,
        sendPaste: @escaping @MainActor () -> Void,
        sleep: @escaping @MainActor (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.pasteboard = pasteboard
        self.sendPaste = sendPaste
        self.sleep = sleep
    }

    public func paste(_ text: String) async {
        let saved = snapshot()
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        await sleep(Self.pasteSettle)
        sendPaste()
        await sleep(Self.restoreDelay)
        restore(saved)
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
