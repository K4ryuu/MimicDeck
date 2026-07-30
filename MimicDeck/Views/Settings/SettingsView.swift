// Settings screen: General, Safety, Permissions, About.

import AppKit
import ServiceManagement
import SwiftUI
import os

struct SettingsView: View {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Settings")

    @Environment(PermissionManager.self) private var permissions
    @Environment(EmergencyStopService.self) private var emergency
    @Environment(UpdateChecker.self) private var updates

    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("themePreference") private var themePreference: ThemePreference = .system
    @AppStorage(DockController.preferenceKey) private var showInDock: Bool = true

    @State private var loginItemError: String?
    /// Set while we push the toggle back, so the revert does not recurse.
    @State private var isRevertingLoginItem: Bool = false

    enum ThemePreference: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: "Match system"
            case .light:  "Light"
            case .dark:   "Dark"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                generalCard
                safetyCard
                permissionsCard
                updatesCard
                aboutCard
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: 720, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backgroundGradient)
        .preferredColorScheme(themePreference.colorScheme)
        .onChange(of: launchAtLogin) { _, newValue in
            guard !isRevertingLoginItem else {
                isRevertingLoginItem = false
                return
            }
            updateLoginItem(enabled: newValue)
        }
        .alert(
            "Couldn't change the login item",
            isPresented: Binding(
                get: { loginItemError != nil },
                set: { if !$0 { loginItemError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { loginItemError = nil }
        } message: {
            Text(loginItemError ?? "")
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.06), Color.accentColor.opacity(0.0)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("Tune defaults, safety controls, and review permissions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var generalCard: some View {
        SectionCard(
            title: "General",
            description: "How MimicDeck behaves on launch and how it looks."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledRow(label: "Launch at login",
                           help: "Start MimicDeck automatically when you log in. Uses macOS Service Management.") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                LabeledRow(label: "Show in Dock",
                           help: "ON shows MimicDeck as a normal app in the Dock. OFF hides the Dock icon and puts a small status item in the menu bar instead. Click it to open the window.") {
                    Toggle("", isOn: Binding(
                        get: { showInDock },
                        set: { newValue in
                            showInDock = newValue
                            DockController.shared.apply(showInDock: newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                LabeledRow(label: "Appearance",
                           help: "Force a light or dark UI, or match the system setting.") {
                    Picker("", selection: $themePreference) {
                        ForEach(ThemePreference.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    private var safetyCard: some View {
        SectionCard(
            title: "Safety",
            description: "Optional global hotkey that stops any running autoclicker or macro from anywhere."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledRow(label: "Emergency stop",
                           help: "When ON, pressing the hotkey below from anywhere stops the running clicker or macro. The key still passes through to the foreground app.") {
                    Toggle("", isOn: Binding(
                        get: { emergency.isEnabled },
                        set: { emergency.isEnabled = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                LabeledRow(label: "Hotkey",
                           help: "The combo that triggers the emergency stop. Default is Esc.") {
                    HotkeyRecorderField(hotkey: Binding(
                        get: { emergency.triggerKey },
                        set: { emergency.setTriggerKey($0) }
                    ))
                    .disabled(!emergency.isEnabled)
                    .opacity(emergency.isEnabled ? 1 : 0.5)
                }
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("The hotkey only fires when something is actively running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var permissionsCard: some View {
        SectionCard(
            title: "Permissions",
            description: "What MimicDeck needs to control other apps."
        ) {
            VStack(spacing: 14) {
                permissionStatusRow(
                    title: "Accessibility",
                    isGranted: permissions.isAccessibilityTrusted,
                    manage: {
                        permissions.requestAccessibilityRegistration()
                        permissions.openSystemSettings()
                    }
                )

                HStack {
                    Spacer()
                    Button("Re-check") { permissions.refresh() }
                        .controlSize(.small)
                }
            }
        }
    }

    private func permissionStatusRow(
        title: String,
        isGranted: Bool,
        manage: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: isGranted ? "checkmark" : "exclamationmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isGranted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(isGranted ? "Granted" : "Not granted")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isGranted ? .green : .orange)
            }

            Spacer()

            Button("Manage…", action: manage)
                .buttonStyle(.borderedProminent)
        }
    }

    private var updatesCard: some View {
        SectionCard(
            title: "Updates",
            description: "The only thing in MimicDeck that talks to the network."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledRow(label: "Check automatically",
                           help: "Asks the GitHub releases page once a day whether a newer version exists. Nothing is downloaded or installed, and turning this off stops every network request the app makes.") {
                    Toggle("", isOn: Binding(
                        get: { updates.isEnabled },
                        set: { updates.isEnabled = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                HStack(spacing: 10) {
                    updateStatusLabel
                    Spacer()
                    if case .updateAvailable = updates.state {
                        Button("Open download page") {
                            NSWorkspace.shared.open(UpdateChecker.releasesPageURL)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    Button("Check now") { updates.check() }
                        .controlSize(.small)
                        .disabled(updates.state == .checking)
                }
            }
        }
    }

    @ViewBuilder
    private var updateStatusLabel: some View {
        switch updates.state {
        case .idle:
            Text("Version \(updates.currentVersion) installed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").font(.caption).foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("You're on the latest version.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .updateAvailable(let version):
            Label("Version \(version) is available.", systemImage: "arrow.down.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
        }
    }

    private var aboutCard: some View {
        SectionCard(
            title: "About",
            description: nil
        ) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledRow(label: "Version") {
                    Text(Bundle.main.shortVersionString)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                LabeledRow(label: "Build") {
                    Text(Bundle.main.buildNumber)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                LabeledRow(label: "Made by") {
                    Link(AppLinks.author, destination: AppLinks.authorPage)
                        .pointingHandCursor()
                }
                LabeledRow(label: "Source") {
                    Link("github.com/\(AppLinks.repositorySlug)", destination: AppLinks.repository)
                        .pointingHandCursor()
                }
            }
        }
    }

    // MARK: - Login item

    /// Service Management refuses unsigned or quarantined builds, so this
    /// really does fail out there. Revert the switch and say why.
    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            Self.log.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
            loginItemError = error.localizedDescription
            // Back without re-entering this handler.
            isRevertingLoginItem = true
            launchAtLogin = !enabled
        }
    }
}

private extension SettingsView.ThemePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

private extension Bundle {
    var shortVersionString: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "-"
    }
    var buildNumber: String {
        (infoDictionary?["CFBundleVersion"] as? String) ?? "-"
    }
}
