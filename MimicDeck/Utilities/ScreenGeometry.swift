// Cocoa and CGEvent disagree on where the screen origin is.
// NSEvent.mouseLocation: bottom-left of the PRIMARY display, y grows up.
// CGEvent: top-left of the PRIMARY display, y grows down.
// So the flip must use the primary height. Using the screen the cursor
// happens to be on looks fine on one monitor and mis-aims every click
// on two.

import AppKit
import CoreGraphics

@MainActor
enum ScreenGeometry {
    /// Height of the display that owns the global origin. That's
    /// `screens.first`, not `NSScreen.main` (which is just the focused one).
    static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
    }

    static func cgPoint(fromCocoa point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func currentCursor() -> CGPoint {
        cgPoint(fromCocoa: NSEvent.mouseLocation)
    }

    /// Same flip without the AppKit lookup, so tests can pin a height.
    nonisolated static func flipY(_ point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
