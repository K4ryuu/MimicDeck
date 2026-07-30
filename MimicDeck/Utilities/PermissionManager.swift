// Accessibility trust: click and key injection, AX queries.
//
// Input Monitoring is deliberately not tracked here. Its preflight check
// reports "denied" on machines where recording works perfectly well through
// Accessibility, so acting on it only produced warnings that were not true.
// MacroRecorder reports what actually happened instead.

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Observation
import os

@MainActor
@Observable
final class PermissionManager {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Permissions")

    private(set) var isAccessibilityTrusted: Bool

    private var pollTask: Task<Void, Never>?

    init() {
        self.isAccessibilityTrusted = AXIsProcessTrusted()
        Self.log.info("Initial Accessibility trust: \(self.isAccessibilityTrusted, privacy: .public)")
    }

    /// Re-read without prompting.
    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isAccessibilityTrusted {
            Self.log.info("Accessibility trust → \(trusted, privacy: .public)")
        }
        isAccessibilityTrusted = trusted
    }

    // MARK: - Prompts and registration

    /// Puts us in the Accessibility list, switched off, without popping the
    /// system dialog. Our onboarding sheet replaces it.
    func requestAccessibilityRegistration() {
        forceAccessibilityRegistration()
        refresh()
        Self.log.info("Requested Accessibility registration. Trusted=\(self.isAccessibilityTrusted, privacy: .public)")
    }

    /// An AX query that fails on purpose. Failing is what registers us with
    /// TCC. Does not touch Input Monitoring.
    private func forceAccessibilityRegistration() {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
    }

    // MARK: - Deep links to System Settings

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Polling

    /// Polls while onboarding is open, so granting access needs no restart.
    func startPolling(interval: Duration = .milliseconds(500)) {
        guard pollTask == nil else { return }
        Self.log.debug("Started polling permissions")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                self?.refresh()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
