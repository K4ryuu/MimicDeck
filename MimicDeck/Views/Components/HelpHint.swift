// Instant hover popover instead of .help(), which sits behind the native
// tooltip delay.

import SwiftUI

struct HelpHint: View {
    let text: String

    @State private var isHovering: Bool = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .foregroundStyle(.tertiary)
            .imageScale(.medium)
            .onHover { hovering in
                isHovering = hovering
            }
            .popover(isPresented: $isHovering, arrowEdge: .top) {
                Text(text)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 280)
                    .fixedSize(horizontal: false, vertical: true)
            }
    }
}
