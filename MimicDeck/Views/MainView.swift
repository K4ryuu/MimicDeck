// Sidebar + detail. Macros gets its own list/editor split inside the detail.
// The onboarding sheet covers everything while Accessibility is missing.

import SwiftUI

struct MainView: View {
    @Environment(PermissionManager.self) private var permissions
    @Environment(MacroStore.self) private var store
    @Environment(Navigation.self) private var navigation

    @State private var macroSelection: UUID?
    /// Starts false so the sheet does not flash when access is already
    /// granted. `task` decides for real.
    @State private var showOnboarding: Bool = false

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView {
            SidebarView(selection: $navigation.section)
                .frame(minWidth: 180)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(onContinue: { showOnboarding = false })
                .interactiveDismissDisabled()
        }
        .task {
            showOnboarding = !permissions.isAccessibilityTrusted
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.section {
        case .autoClicker, .none:
            AutoClickerView()
                .frame(minWidth: 640, minHeight: 540)
        case .macros:
            macrosLayout
        case .settings:
            SettingsView()
                .frame(minWidth: 640, minHeight: 540)
        }
    }

    private var macrosLayout: some View {
        HStack(spacing: 0) {
            MacroListView(selection: $macroSelection)
                .frame(width: 240)
                .frame(maxHeight: .infinity)

            Divider()

            Group {
                if let id = macroSelection, store.macros.contains(where: { $0.id == id }) {
                    MacroEditorView(macroID: id)
                } else {
                    ContentUnavailableView("Select a macro", systemImage: "square.dashed")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}
