// Publishes the frontmost app's bundle id so the engine can gate
// window-bound macros. NSWorkspace notifications, no polling.

import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class WindowWatcher {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Windows")

    private(set) var frontmostBundleIdentifier: String?

    private var observers: [NSObjectProtocol] = []

    init() {
        refreshFrontmost()
        let center = NSWorkspace.shared.notificationCenter

        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { @Sendable [weak self] note in
            let bundle = (note.userInfo?[NSWorkspace.applicationUserInfoKey]
                          as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor [weak self] in
                self?.update(bundle)
            }
        })
    }

    // Lives for the app lifetime, so no deinit cleanup.

    /// Regular running apps, for the picker.
    func runningApps() -> [AppEntry] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundle = app.bundleIdentifier else { return nil }
                return AppEntry(
                    bundleIdentifier: bundle,
                    displayName: app.localizedName ?? bundle,
                    icon: app.icon
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func refreshFrontmost() {
        frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func update(_ bundle: String?) {
        guard bundle != frontmostBundleIdentifier else { return }
        Self.log.debug("Frontmost → \(bundle ?? "nil", privacy: .public)")
        frontmostBundleIdentifier = bundle
    }

    struct AppEntry: Identifiable, Hashable {
        var id: String { bundleIdentifier }
        let bundleIdentifier: String
        let displayName: String
        let icon: NSImage?

        static func == (lhs: AppEntry, rhs: AppEntry) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(bundleIdentifier)
        }
    }
}
