import CoreGraphics
import Testing
@testable import ParleyCore

@Suite struct HUDPlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1728, height: 1084)
    let pill = CGSize(width: 520, height: 84)

    @Test func sitsInsideTheBottomOfANormalWindow() {
        let window = CGRect(x: 100, y: 200, width: 900, height: 700)
        let origin = HUDPlacement.origin(window: window, visible: screen, size: pill)
        #expect(origin == CGPoint(x: 290, y: 240))
    }

    @Test func goesBelowABarSoItDoesNotCoverTheField() {
        // Spotlight: 640×56, its field is the whole window.
        let bar = CGRect(x: 544, y: 792, width: 640, height: 56)
        let origin = HUDPlacement.origin(window: bar, visible: screen, size: pill)
        #expect(origin.y + pill.height <= bar.minY)
        #expect(origin.x == bar.midX - pill.width / 2)
    }

    @Test func goesAboveABarAtTheBottomOfTheScreen() {
        let bar = CGRect(x: 544, y: 20, width: 640, height: 56)
        let origin = HUDPlacement.origin(window: bar, visible: screen, size: pill)
        #expect(origin.y >= bar.maxY)
    }

    @Test func staysOnScreenForAWindowHangingOffTheEdge() {
        let window = CGRect(x: 1500, y: -300, width: 800, height: 900)
        let origin = HUDPlacement.origin(window: window, visible: screen, size: pill)
        #expect(origin.x + pill.width <= screen.maxX)
        #expect(origin.y == screen.minY + HUDPlacement.inset)
    }

    @Test func flipsAccessibilityCoordinates() {
        let rect = HUDPlacement.cocoaRect(fromTopLeft: CGRect(x: 10, y: 33, width: 100, height: 50), primaryMaxY: 1117)
        #expect(rect == CGRect(x: 10, y: 1034, width: 100, height: 50))
    }
}
