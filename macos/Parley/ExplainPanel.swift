import AppKit
import ParleyCore
import SwiftUI

@MainActor
@Observable
final class ExplainModel {
    var content: ExplainContent = .empty
}

/// The Explain card: a glass popover anchored under the selection. It takes
/// clicks (copy, sources, close) but never focus, so the selection the user
/// asked about stays selected in their app.
@MainActor
final class ExplainPanel {
    static let width: CGFloat = 440
    static let maxHeight: CGFloat = 520

    let model = ExplainModel()
    private let panel: NSPanel
    private let host: NSHostingView<ExplainCard>
    private var anchor: CGRect?
    private var outsideClicks: Any?

    var onDismiss: () -> Void = {}
    var onCopy: (String) -> Void = { _ in }

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        host = NSHostingView(rootView: ExplainCard(model: model, copy: { _ in }, close: {}))
        panel.contentView = host
        host.rootView = ExplainCard(
            model: model,
            copy: { [weak self] text in self?.onCopy(text) },
            close: { [weak self] in self?.onDismiss() }
        )
    }

    var isVisible: Bool { panel.isVisible }

    /// `anchor` is the selection in Accessibility's top-left coordinates.
    func show(anchor: CGRect?, content: ExplainContent) {
        self.anchor = anchor
        model.content = content
        resizeAndPlace()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
        watchOutsideClicks()
    }

    func update(_ content: ExplainContent) {
        model.content = content
        resizeAndPlace()
    }

    func hide() {
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
    }

    /// The panel never has focus, so there is no blur to listen for: a click
    /// anywhere else is the dismissal.
    private func watchOutsideClicks() {
        guard outsideClicks == nil else { return }
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) { self.onDismiss() }
            }
        }
    }

    private func resizeAndPlace() {
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        let height = min(max(fitting.height, 96), Self.maxHeight)
        let size = NSSize(width: Self.width, height: height)

        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        var origin: NSPoint
        if let anchor {
            // Under the selection; above it if there is no room below.
            let selection = NSRect(x: anchor.minX, y: primaryTop - anchor.maxY, width: anchor.width, height: anchor.height)
            origin = NSPoint(x: selection.minX, y: selection.minY - 10 - height)
            let visible = screenFrame(containing: NSPoint(x: selection.midX, y: selection.midY))
            if origin.y < visible.minY { origin.y = selection.maxY + 10 }
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - Self.width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - height - 8)
        } else {
            let mouse = NSEvent.mouseLocation
            let visible = screenFrame(containing: mouse)
            origin = NSPoint(
                x: min(max(mouse.x - Self.width / 2, visible.minX + 8), visible.maxX - Self.width - 8),
                y: min(max(mouse.y - height - 16, visible.minY + 8), visible.maxY - height - 8)
            )
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func screenFrame(containing point: NSPoint) -> NSRect {
        (NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main)?.visibleFrame ?? .zero
    }
}

struct ExplainCard: View {
    let model: ExplainModel
    let copy: (String) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array((model.content.turns ?? []).enumerated()), id: \.offset) { _, turn in
                        TurnView(turn: turn)
                    }
                    if model.content.status == "empty" {
                        Text("Select some text, then ask.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: ExplainPanel.width)
        .frame(maxHeight: ExplainPanel.maxHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var lastAnswer: String? {
        model.content.turns?.last(where: { $0.markdown?.isEmpty == false })?.markdown
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .foregroundStyle(Brand.hue(for: "explain"))
            Text("Explain")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let lastAnswer {
                Button { copy(lastAnswer) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Copy the answer")
                    .accessibilityLabel("Copy the answer")
            }
            Button { close() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Close (Esc)")
                .accessibilityLabel("Close")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

private struct TurnView: View {
    let turn: ExplainTurn

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let question = turn.question, !question.isEmpty {
                Text(question)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            if let markdown = turn.markdown, !markdown.isEmpty {
                Text(Self.render(markdown))
                    .font(.system(size: 13.5))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch turn.status {
            case "loading", "streaming":
                if turn.markdown?.isEmpty != false || turn.searching != nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(turn.searching.map { "Searching “\($0)”…" } ?? "Thinking…")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                }
            case "error":
                Label(turn.message ?? "Something went wrong", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
            if let sources = turn.sources, !sources.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sources, id: \.self) { source in
                        if let url = URL(string: source.url), ["http", "https"].contains(url.scheme ?? "") {
                            Link(source.title.isEmpty ? source.url : source.title, destination: url)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    static func render(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}
