// Left column: three destinations plus a footer with branding and run state.

import Observation
import SwiftUI

/// Which section the window shows. Observable so Cmd-, can navigate here
/// instead of opening another window.
@MainActor
@Observable
final class Navigation {
    var section: SidebarSection? = .autoClicker
}

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case autoClicker
    case macros
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .autoClicker:  "Auto Clicker"
        case .macros:       "Macros"
        case .settings:     "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .autoClicker:  "cursorarrow.click.2"
        case .macros:       "square.stack.3d.up"
        case .settings:     "gearshape"
        }
    }
}

struct SidebarView: View {
    @Environment(MacroEngine.self) private var engine
    @Binding var selection: SidebarSection?

    var body: some View {
        VStack(spacing: 0) {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)

            Divider()
            footer
        }
        .navigationTitle("MimicDeck")
    }

    private var footer: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.85),
                                     Color.accentColor.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("MimicDeck")
                    .font(.callout.weight(.semibold))
                if engine.isRunning {
                    Text("Running…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 3) {
                        Text("by")
                            .foregroundStyle(.secondary)
                        Link(AppLinks.author, destination: AppLinks.authorPage)
                            .pointingHandCursor()
                            .help("Open github.com/\(AppLinks.author)")
                    }
                    .font(.caption2)
                }
            }

            Spacer()

            if engine.isRunning {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.small)
                    .symbolEffect(.pulse, options: .repeating)
            }
        }
        .frame(height: 36)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
