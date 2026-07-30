// Pick a screen point by clicking anywhere. Dim overlay across all screens,
// click captures, Esc cancels. Result is in CGEvent space.

import AppKit
import Foundation

@MainActor
enum PositionPicker {
    /// Completion fires once: the point, or nil if cancelled.
    static func pick(completion: @escaping (CGPoint?) -> Void) {
        let window = PickerOverlayWindow(completion: completion)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class PickerOverlayWindow: NSWindow {
    private let onPick: (CGPoint?) -> Void
    private var localMonitor: Any?
    private var hasPicked = false

    init(completion: @escaping (CGPoint?) -> Void) {
        self.onPick = completion

        // Cover all attached screens.
        let unionFrame = NSScreen.screens.reduce(NSScreen.main?.frame ?? .zero) { union, screen in
            union.union(screen.frame)
        }

        super.init(
            contentRect: unionFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.18)
        level = .screenSaver
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = OverlayContentView()
        contentView?.frame = unionFrame

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 0x35 { // Esc
                self?.cancel()
                return nil
            }
            return event
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard !hasPicked else { return }
        hasPicked = true

        onPick(ScreenGeometry.currentCursor())
        teardown()
    }

    private func cancel() {
        guard !hasPicked else { return }
        hasPicked = true
        onPick(nil)
        teardown()
    }

    private func teardown() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        orderOut(nil)
    }
}

private final class OverlayContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let centerY = bounds.height / 2
        let banner = NSRect(x: bounds.midX - 200, y: centerY - 30, width: 400, height: 60)

        let path = NSBezierPath(roundedRect: banner, xRadius: 12, yRadius: 12)
        NSColor.black.withAlphaComponent(0.65).setFill()
        path.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]
        let title = "Click anywhere to pick a position"
        let titleSize = (title as NSString).size(withAttributes: attrs)
        (title as NSString).draw(
            at: NSPoint(x: banner.midX - titleSize.width / 2, y: banner.midY - 4),
            withAttributes: attrs
        )

        let sub = "Esc to cancel"
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
            .paragraphStyle: style
        ]
        let subSize = (sub as NSString).size(withAttributes: subAttrs)
        (sub as NSString).draw(
            at: NSPoint(x: banner.midX - subSize.width / 2, y: banner.minY + 6),
            withAttributes: subAttrs
        )
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }
}
