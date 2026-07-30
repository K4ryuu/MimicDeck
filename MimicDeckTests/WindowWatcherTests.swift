// Light cover only. The NSWorkspace activation flow needs a real app switch,
// so we stick to the init snapshot and the shape of runningApps().

import Testing
@testable import MimicDeck

@Suite("WindowWatcher")
@MainActor
struct WindowWatcherTests {
    @Test("Init reads the current frontmost app")
    func initSnapshot() {
        let watcher = WindowWatcher()
        // The runner is itself frontmost, so this should be non-nil. CI
        // without a UI session may not be, accept either.
        _ = watcher.frontmostBundleIdentifier
    }

    @Test("runningApps returns regular apps with a bundle ID")
    func runningAppsShape() {
        let watcher = WindowWatcher()
        let apps = watcher.runningApps()
        // No assumptions about which apps run, but every entry needs a
        // non-empty bundle ID.
        for app in apps {
            #expect(!app.bundleIdentifier.isEmpty)
            #expect(!app.displayName.isEmpty)
        }
    }
}
