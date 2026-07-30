// One permission row: status icon, title, badge, description, action button.
// isRequired = false gives the softer "Optional" treatment.

import SwiftUI

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let isPending: Bool
    var isRequired: Bool = true
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .center, spacing: 6) {
                Button(action: action) {
                    Text(isGranted ? "Manage…" : "Enable")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .tint(isGranted ? .secondary : .accentColor)

                statusBadge
            }
            .frame(width: 110)
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackground)
                .frame(width: 36, height: 36)
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconForeground)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
                .font(.caption2.weight(.bold))
            Text(badgeText)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(badgeColor)
        .frame(maxWidth: .infinity)
    }

    // MARK: - State-derived styling

    private var badgeText: String {
        if isGranted { return "Granted" }
        if isPending { return "Waiting…" }
        return isRequired ? "Required" : "Optional"
    }

    private var badgeIcon: String {
        if isGranted { return "checkmark.circle.fill" }
        if isPending { return "ellipsis.circle.fill" }
        return isRequired ? "exclamationmark.circle.fill" : "info.circle.fill"
    }

    private var badgeColor: Color {
        if isGranted { return .green }
        if isPending { return .orange }
        return isRequired ? .orange : .secondary
    }

    private var iconName: String {
        if isGranted { return "checkmark" }
        return isRequired ? "exclamationmark" : "questionmark"
    }

    private var iconBackground: Color {
        if isGranted { return .green.opacity(0.18) }
        return isRequired ? .orange.opacity(0.18) : .secondary.opacity(0.18)
    }

    private var iconForeground: Color {
        if isGranted { return .green }
        return isRequired ? .orange : .secondary
    }

    private var borderColor: Color {
        if isGranted { return .green.opacity(0.25) }
        return isRequired ? .orange.opacity(0.25) : .secondary.opacity(0.18)
    }
}

#Preview {
    VStack(spacing: 12) {
        PermissionRow(
            title: "Accessibility",
            description: "Required for clicks and keys.",
            isGranted: false,
            isPending: false,
            action: {}
        )
        PermissionRow(
            title: "Input Monitoring",
            description: "Optional. Only needed for key recording.",
            isGranted: false,
            isPending: false,
            isRequired: false,
            action: {}
        )
        PermissionRow(
            title: "Accessibility",
            description: "Granted.",
            isGranted: true,
            isPending: false,
            action: {}
        )
    }
    .padding(32)
    .frame(width: 560)
}
