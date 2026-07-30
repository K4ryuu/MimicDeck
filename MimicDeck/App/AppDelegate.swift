// Thin NSApplicationDelegate. Forces a real window minimum size, pulls the
// window up front on launch, handles dock reopen.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let minimumContentSize = NSSize(width: 1080, height: 640)

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            // Otherwise the window can land in "needs attention" and the
            // user has to click the bouncing dock icon.
            NSApp.activate(ignoringOtherApps: true)
            self.applyMinimumContentSize()
            NSApp.windows.first(where: { $0.canBecomeMain })?
                .makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first(where: { $0.canBecomeMain })?
                .makeKeyAndOrderFront(nil)
        }
        applyMinimumContentSize()
        return true
    }

    /// In menu-bar-only mode the status item is the only way back in, so
    /// closing the window must not quit.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return NSApp.activationPolicy() == .regular
    }

    private func applyMinimumContentSize() {
        for window in NSApp.windows where window.canBecomeMain {
            window.contentMinSize = Self.minimumContentSize
            if window.frame.width < Self.minimumContentSize.width
                || window.frame.height < Self.minimumContentSize.height {
                var frame = window.frame
                frame.size.width = max(frame.width, Self.minimumContentSize.width)
                frame.size.height = max(frame.height, Self.minimumContentSize.height)
                window.setFrame(frame, display: true, animate: false)
            }
        }
    }
}
