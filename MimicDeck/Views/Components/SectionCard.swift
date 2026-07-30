// Section container: small uppercase title, optional description, bordered
// card body. Same rhythm across Auto Clicker, Macro Editor and Settings.

import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    var description: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.separator.opacity(0.4), lineWidth: 1)
                )
        }
    }
}

/// Label, spacer, control. The standard row inside a SectionCard.
struct LabeledRow<Content: View>: View {
    let label: String
    var help: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(label)
                if let help { HelpHint(text: help) }
            }
            Spacer()
            content()
        }
    }
}
