// TextField + Stepper. Type a value or step it. The binding updates while
// typing so dependent labels like "(infinite)" keep up.

import SwiftUI

struct NumberField: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...1_000_000
    var step: Int = 10
    var unit: String? = nil
    var width: CGFloat = 84

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $text)
                .focused($focused)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
                .onAppear { text = String(value) }
                .onChange(of: text) { _, newText in
                    propagateTextToValue(newText)
                }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { normalizeText() }
                }
                .onSubmit { normalizeText() }
                .onChange(of: value) { _, newValue in
                    // Stepper and friends overwrite the text. While focused,
                    // the user owns it.
                    if !focused, text != String(newValue) {
                        text = String(newValue)
                    }
                }

            if let unit {
                Text(unit)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }

    /// Push valid values straight through. Partial input like "-" waits.
    private func propagateTextToValue(_ newText: String) {
        let filtered = newText.filter { $0.isNumber || $0 == "-" }
        guard let parsed = Int(filtered) else { return }
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        if clamped != value {
            value = clamped
        }
    }

    /// Snap back to a clean number on blur.
    private func normalizeText() {
        let filtered = text.filter { $0.isNumber || $0 == "-" }
        let parsed = Int(filtered) ?? value
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        value = clamped
        text = String(clamped)
    }
}

#Preview {
    @Previewable @State var v1 = 150
    @Previewable @State var v2 = 5000
    return VStack(spacing: 16) {
        NumberField(value: $v1, range: 1...60_000, step: 10, unit: "ms")
        NumberField(value: $v2, range: 1...3_600_000, step: 500, unit: "ms", width: 110)
    }
    .padding(40)
}
