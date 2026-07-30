// Regression cover for the Cocoa to CGEvent flip. The old code flipped
// around whichever display the cursor was on, which only works on one monitor.

import CoreGraphics
import Testing
@testable import MimicDeck

@Suite("ScreenGeometry")
struct ScreenGeometryTests {
    @Test("Bottom-left origin maps to the bottom of the primary display")
    func originMapsToBottom() {
        let flipped = ScreenGeometry.flipY(CGPoint(x: 0, y: 0), primaryHeight: 1080)
        #expect(flipped == CGPoint(x: 0, y: 1080))
    }

    @Test("Top of the primary display maps to y = 0")
    func topMapsToZero() {
        let flipped = ScreenGeometry.flipY(CGPoint(x: 640, y: 1080), primaryHeight: 1080)
        #expect(flipped == CGPoint(x: 640, y: 0))
    }

    @Test("x is never touched")
    func horizontalUnchanged() {
        let flipped = ScreenGeometry.flipY(CGPoint(x: 2400, y: 300), primaryHeight: 1080)
        #expect(flipped.x == 2400)
    }

    @Test("A point on a taller secondary display still flips around the primary height")
    func secondaryDisplayUsesPrimaryHeight() {
        // Primary is 1080 tall, cursor sits at y 1200 on a 1440 tall display
        // next to it. Flipping around 1440 gives 240. The right answer is
        // negative: above the primary display's top edge.
        let flipped = ScreenGeometry.flipY(CGPoint(x: 3000, y: 1200), primaryHeight: 1080)
        #expect(flipped.y == -120)
    }
}
