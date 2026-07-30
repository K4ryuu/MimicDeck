// First-run sheet while a required permission is missing. Stays up after the
// grant so the user leaves on their own terms.

import AppKit
import SwiftUI

struct OnboardingView: View {
    @Environment(PermissionManager.self) private var permissions
    @State private var attemptedAccessibility: Bool = false

    var onContinue: () -> Void

    private var hasAttempted: Bool { attemptedAccessibility }

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)
                hero
                Spacer(minLength: 24)

                permissionsSection
                    .padding(.horizontal, 32)

                Spacer(minLength: 16)
                statusLine
                    .padding(.horizontal, 32)

                Spacer(minLength: 20)
                actionBar
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)
            }
        }
        .frame(minWidth: 580, minHeight: 430)
        .onAppear { permissions.startPolling() }
        .onDisappear { permissions.stopPolling() }
    }

    // MARK: - Sections

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.10),
                Color.accentColor.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .background(.background)
    }

    private var hero: some View {
        VStack(spacing: 18) {
            heroIcon

            VStack(spacing: 6) {
                Text("Welcome to MimicDeck")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text(permissions.isAccessibilityTrusted
                     ? "You're all set."
                     : "One last step before you start automating.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var heroIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 78, height: 78)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 16, x: 0, y: 8)

            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            PermissionRow(
                title: "Accessibility",
                description: "Required. Lets MimicDeck send clicks and keys to other apps, and capture mouse input while recording.",
                isGranted: permissions.isAccessibilityTrusted,
                isPending: attemptedAccessibility && !permissions.isAccessibilityTrusted,
                action: enableAccessibility
            )
        }
    }

    private var statusLine: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusTint)
                    .font(.title3)
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if showsStaleEntryHint {
                Text("Already in the list but still not working? An entry left by an older build is a different app to macOS. Select it, press the minus button to remove it, then click Enable again.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// macOS keys permissions to the code signature, so a rebuild or a rename
    /// leaves the old row behind, switched on and doing nothing. The app cannot
    /// clear that itself, only the user can.
    private var showsStaleEntryHint: Bool {
        attemptedAccessibility && !permissions.isAccessibilityTrusted
    }

    private var statusIcon: String {
        if permissions.isAccessibilityTrusted { return "checkmark.seal.fill" }
        if hasAttempted { return "arrow.triangle.2.circlepath" }
        return "info.circle"
    }

    private var statusTint: Color {
        if permissions.isAccessibilityTrusted { return .green }
        if hasAttempted { return .orange }
        return .secondary
    }

    private var statusText: String {
        if permissions.isAccessibilityTrusted {
            return "Permission granted. Click Continue when you're ready."
        }
        if hasAttempted {
            return "Waiting for you to toggle MimicDeck on in System Settings."
        }
        return "Status refreshes automatically. No need to restart."
    }

    @ViewBuilder
    private var actionBar: some View {
        if permissions.isAccessibilityTrusted {
            Button(action: onContinue) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        } else {
            HStack {
                Spacer()
                Button("Quit MimicDeck", action: quit)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Actions

    /// A window with a sheet attached refuses to close, and NSApp.terminate
    /// sits waiting on exactly that. Drop the sheet first, quit on the next
    /// turn of the run loop.
    private func quit() {
        onContinue()
        Task { @MainActor in
            NSApp.terminate(nil)
        }
    }

    private func enableAccessibility() {
        attemptedAccessibility = true
        permissions.requestAccessibilityRegistration()
        permissions.openSystemSettings()
    }

}
