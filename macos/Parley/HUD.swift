import AppKit
import ParleyCore
import SwiftUI

/// What the pill shows. Driven by the engine's `hud.*` notifications and the
/// recorder's level.
@MainActor
@Observable
final class HUDModel {
    static let barCount = 14

    var phase: HUDPhase.Phase = .listening
    var message: String?
    var levels: [Float] = Array(repeating: 0, count: barCount)
    var startedAt = Date()

    func push(level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    func reset() {
        levels = Array(repeating: 0, count: Self.barCount)
        startedAt = Date()
        message = nil
    }
}

/// A borderless, non-activating panel: it floats over every app and space,
/// never takes focus from the field being dictated into, and lets clicks
/// through.
@MainActor
final class HUDPanel {
    let model = HUDModel()
    private let panel: NSPanel
    private static let size = NSSize(width: 420, height: 72)

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

    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - Self.size.width / 2, y: frame.minY + 48))
        }
        model.reset()
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
    }
}

struct HUDView: View {
    let model: HUDModel

    var body: some View {
        HStack(spacing: 12) {
            badge
            content
        }
        .padding(.leading, 9)
        .padding(.trailing, 20)
        .frame(height: 52)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.25), value: model.phase)
    }

    @ViewBuilder private var badge: some View {
        switch model.phase {
        case .listening:
            Circle()
                .fill(Color.accentColor)
                .frame(width: 34, height: 34)
                .shadow(color: .accentColor.opacity(0.6), radius: 10)
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 34, height: 34)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.red)
        case .notice:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .listening:
            HStack(spacing: 3) {
                ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.45 + Double(level) * 0.55))
                        .frame(width: 4, height: 6 + CGFloat(level) * 22)
                }
            }
            .frame(height: 28)
            .animation(.linear(duration: 0.08), value: model.levels)
            TimelineView(.periodic(from: model.startedAt, by: 1)) { context in
                Text(elapsed(since: model.startedAt, now: context.date))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
        case .transcribing:
            Text("Writing it down…").font(.system(size: 13.5, weight: .medium))
        case .done:
            Text("Pasted").font(.system(size: 13.5, weight: .medium))
        case .error:
            Text(model.message ?? "Something went wrong")
                .font(.system(size: 13.5, weight: .semibold))
                .lineLimit(2)
        case .cancelled:
            Text("Cancelled").font(.system(size: 13.5, weight: .medium))
        case .notice:
            Text(model.message ?? "").font(.system(size: 13.5, weight: .medium))
        }
    }

    private func elapsed(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
