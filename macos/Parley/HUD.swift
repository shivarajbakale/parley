import AppKit
import ParleyCore
import SwiftUI

/// Parley's colours: violet for dictation (the brand), and one hue per mode
/// so the pill says which gesture you made before you speak.
enum Brand {
    static let violet = Color(red: 0x5B / 255, green: 0x3D / 255, blue: 0xF5 / 255)
    static let violetBright = Color(red: 0x8F / 255, green: 0x7C / 255, blue: 0xFF / 255)

    static func hue(for mode: String?) -> Color {
        switch mode {
        case "edit": Color(red: 0.75, green: 0.35, blue: 0.95)
        case "explain": Color(red: 0.19, green: 0.69, blue: 0.78)
        case "act": Color(red: 1.0, green: 0.62, blue: 0.04)
        default: violetBright
        }
    }

    static func label(for mode: String?) -> String {
        switch mode {
        case "edit": "Voice edit"
        case "explain": "Explain"
        case "act": "Act"
        default: "Listening"
        }
    }
}

/// What the pill shows. Driven by the engine's `hud.*` notifications and the
/// recorder's level.
@MainActor
@Observable
final class HUDModel {
    static let barCount = 14

    var phase: HUDPhase.Phase = .listening
    var message: String?
    var hint: String?
    var accepted = false
    var mode: String?
    var levels: [Float] = Array(repeating: 0, count: barCount)
    var startedAt = Date()

    func apply(_ update: HUDPhase) {
        phase = update.phase
        message = update.message
        hint = update.hint
        accepted = update.accepted
        // The mode is set when a session starts and worn until it ends.
        if update.phase == .listening { mode = update.mode }
    }

    func push(level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    func reset() {
        levels = Array(repeating: 0, count: Self.barCount)
        startedAt = Date()
        message = nil
        hint = nil
        accepted = false
    }
}

/// A borderless, non-activating panel: it floats over every app and space,
/// never takes focus from the field being dictated into, and lets clicks
/// through. It sits at the bottom of the window the user is working in.
@MainActor
final class HUDPanel {
    let model = HUDModel()
    private let panel: NSPanel
    private static let size = NSSize(width: 520, height: 84)
    private var placement = 0

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
    }

    /// Ours, not AppKit's: during the fade-out the panel is still visible and
    /// its alpha is mid-animation, so neither says whether it is showing.
    private(set) var isVisible = false

    func show() {
        if !isVisible {
            isVisible = true
            model.reset()
            // At once on the mouse's screen, then onto the user's window once
            // Accessibility says where it is (it can be on another display).
            place(in: Self.screenFrame(containing: NSEvent.mouseLocation))
            placement += 1
            let mine = placement
            Task.detached(priority: .userInitiated) {
                let window = Accessibility.frontWindowBounds()
                await MainActor.run {
                    guard mine == self.placement, let window else { return }
                    self.place(onto: window)
                }
            }
        }
        // Cancels a fade-out still running from the last session, whose
        // completion would otherwise order this one out.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 1
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        placement += 1
        let mine = placement
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // A new session began during the fade: leave it on screen.
                guard let self, mine == self.placement, !self.isVisible else { return }
                self.panel.orderOut(nil)
            }
        })
    }

    private static func screenFrame(containing point: NSPoint) -> NSRect {
        (NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main)?.visibleFrame ?? .zero
    }

    private func place(in frame: NSRect) {
        panel.setFrameOrigin(NSPoint(x: frame.midX - Self.size.width / 2, y: frame.minY + HUDPlacement.inset))
    }

    /// `window` is in Accessibility's top-left coordinates.
    private func place(onto window: CGRect) {
        guard let primary = NSScreen.screens.first else { return }
        let flipped = HUDPlacement.cocoaRect(fromTopLeft: window, primaryMaxY: primary.frame.maxY)
        let visible = Self.screenFrame(containing: NSPoint(x: flipped.midX, y: flipped.midY))
        panel.setFrameOrigin(HUDPlacement.origin(window: flipped, visible: visible, size: Self.size))
    }
}

struct HUDView: View {
    let model: HUDModel

    private var hue: Color { Brand.hue(for: model.mode) }

    var body: some View {
        HStack(spacing: 12) {
            badge
            content
        }
        .padding(.leading, 9)
        .padding(.trailing, 20)
        .frame(minHeight: 52)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.25), value: model.phase)
    }

    @ViewBuilder private var badge: some View {
        switch model.phase {
        case .listening:
            Circle()
                .fill(hue)
                .frame(width: 34, height: 34)
                .shadow(color: hue.opacity(0.6), radius: 10)
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 34, height: 34)
        case .done:
            symbol("checkmark.circle.fill", .green)
        case .error:
            symbol("exclamationmark.circle.fill", .red)
        case .notice:
            symbol(model.accepted ? "checkmark.circle.fill" : noticeSymbol, model.accepted ? .green : hue)
        case .cancelled:
            symbol("xmark.circle.fill", .secondary)
        }
    }

    private var noticeSymbol: String {
        switch model.mode {
        case "act": "sparkles"
        default: "text.badge.plus"
        }
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 28))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .listening:
            VStack(alignment: .leading, spacing: 1) {
                if model.mode != nil {
                    Text(Brand.label(for: model.mode))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                            Capsule()
                                .fill(hue.opacity(0.45 + Double(level) * 0.55))
                                .frame(width: 4, height: 6 + CGFloat(level) * 22)
                        }
                    }
                    .frame(height: 28)
                    .animation(.linear(duration: 0.08), value: model.levels)
                    TimelineView(.periodic(from: model.startedAt, by: 1)) { context in
                        Text(elapsed(since: model.startedAt, now: context.date))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    }
                }
            }
        case .transcribing:
            Text(model.mode == "edit" ? "Rewriting…" : model.mode == "explain" ? "Thinking…" : "Writing it down…")
                .font(.system(size: 13.5, weight: .medium))
        case .done:
            Text("Done").font(.system(size: 13.5, weight: .medium))
        case .error:
            Text(model.message ?? "Something went wrong")
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(2)
        case .cancelled:
            Text("Cancelled").font(.system(size: 13.5, weight: .medium))
        case .notice:
            VStack(alignment: .leading, spacing: 2) {
                Text(model.message ?? "")
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(2)
                if let hint = model.hint, !model.accepted {
                    Text(hint)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func elapsed(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
