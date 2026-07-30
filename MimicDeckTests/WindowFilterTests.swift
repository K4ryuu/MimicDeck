// The allows(...) decision.

import Testing
@testable import MimicDeck

@Suite("WindowFilter")
struct WindowFilterTests {
    @Test("Allows when frontmost matches bundle ID")
    func matchAllows() {
        let filter = WindowFilter(bundleIdentifier: "com.example", displayName: "Example")
        #expect(filter.allows(frontmostBundleIdentifier: "com.example"))
    }

    @Test("Blocks when frontmost differs")
    func mismatchBlocks() {
        let filter = WindowFilter(bundleIdentifier: "com.example", displayName: "Example")
        #expect(!filter.allows(frontmostBundleIdentifier: "com.other"))
        #expect(!filter.allows(frontmostBundleIdentifier: nil))
    }

    @Test("requireFrontmost=false allows anything")
    func anyAllowed() {
        let filter = WindowFilter(bundleIdentifier: "com.example",
                                  displayName: "Example",
                                  requireFrontmost: false)
        #expect(filter.allows(frontmostBundleIdentifier: "com.other"))
        #expect(filter.allows(frontmostBundleIdentifier: nil))
    }
}
