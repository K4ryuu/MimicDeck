// Locks a macro to one app. Matched on bundle ID so renaming the app does
// not break it.

import Foundation

nonisolated struct WindowFilter: Codable, Hashable, Sendable {
    var bundleIdentifier: String
    var displayName: String
    var requireFrontmost: Bool

    init(bundleIdentifier: String, displayName: String, requireFrontmost: Bool = true) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.requireFrontmost = requireFrontmost
    }

    func allows(frontmostBundleIdentifier: String?) -> Bool {
        if !requireFrontmost { return true }
        return frontmostBundleIdentifier == bundleIdentifier
    }
}
