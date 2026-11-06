import CoreGraphics

/// Where the dictation pill goes, in Cocoa screen coordinates (origin at the
/// bottom left). Pure geometry, so the rules are tested without a display.
public enum HUDPlacement {
    /// Below this height a window is a bar (Spotlight, a launcher, a small
    /// panel): the pill would cover its text field, so it goes underneath.
    public static let barHeight: CGFloat = 220
    public static let inset: CGFloat = 40
    public static let gap: CGFloat = 12
    public static let margin: CGFloat = 8

    /// `window` and `visible` are both in Cocoa coordinates; `visible` is the
    /// visible frame of the screen the window is on.
    public static func origin(window: CGRect, visible: CGRect, size: CGSize) -> CGPoint {
        let x = min(max(window.midX - size.width / 2, visible.minX + margin), visible.maxX - size.width - margin)
        let y: CGFloat
        if window.height >= barHeight {
            // Inside the window, near its bottom edge (or the screen's, if
            // the window runs off it).
            y = max(window.minY, visible.minY) + inset
        } else if window.minY - gap - size.height >= visible.minY {
            y = window.minY - gap - size.height
        } else {
            y = min(window.maxY + gap, visible.maxY - size.height)
        }
        return CGPoint(x: x, y: y)
    }

    /// Accessibility's top-left rect, flipped against the primary screen.
    public static func cocoaRect(fromTopLeft rect: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }
}
