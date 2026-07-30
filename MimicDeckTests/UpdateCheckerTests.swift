// Version comparison for the update check. A plain string compare gets 1.10
// vs 1.9 wrong, which is exactly the case that shows up after ten releases.

import Testing
@testable import MimicDeck

@Suite("UpdateChecker.isNewer")
struct UpdateCheckerVersionTests {
    @Test("A higher patch is newer")
    func higherPatch() {
        #expect(UpdateChecker.isNewer("1.0.1", than: "1.0.0"))
    }

    @Test("The same version is not newer")
    func sameVersion() {
        #expect(!UpdateChecker.isNewer("1.0.0", than: "1.0.0"))
    }

    @Test("An older version is not newer")
    func olderVersion() {
        #expect(!UpdateChecker.isNewer("0.9.9", than: "1.0.0"))
    }

    @Test("Components compare numerically, not as text")
    func numericNotLexicographic() {
        #expect(UpdateChecker.isNewer("1.10.0", than: "1.9.0"))
        #expect(!UpdateChecker.isNewer("1.9.0", than: "1.10.0"))
    }

    @Test("A leading v on the tag is ignored")
    func toleratesTagPrefix() {
        #expect(UpdateChecker.isNewer("v1.1.0", than: "1.0.0"))
        #expect(!UpdateChecker.isNewer("v1.0.0", than: "1.0.0"))
    }

    @Test("Missing components count as zero")
    func shorterVersions() {
        #expect(UpdateChecker.isNewer("1.1", than: "1.0.9"))
        #expect(!UpdateChecker.isNewer("1.0", than: "1.0.0"))
        #expect(UpdateChecker.isNewer("2", than: "1.9.9"))
    }

    @Test("Suffixes like -beta don't break the compare")
    func toleratesSuffixes() {
        #expect(UpdateChecker.isNewer("1.2.0-beta", than: "1.1.0"))
        #expect(!UpdateChecker.isNewer("1.0.0-beta", than: "1.0.0"))
    }

    @Test("Garbage is never treated as an update")
    func garbageIsNotAnUpdate() {
        #expect(!UpdateChecker.isNewer("", than: "1.0.0"))
        #expect(!UpdateChecker.isNewer("latest", than: "1.0.0"))
    }
}
