// Inline editors for individual MacroSteps. Each takes a Binding<MacroStep>
// so edits flow back through the parent macro.

import SwiftUI

// MARK: - Click step

struct ClickStepEditor: View {
    @Binding var step: MacroStep

    var body: some View {
        if case .click(let id, let button, let position) = step {
            HStack(spacing: 8) {
                Picker("", selection: Binding(
                    get: { button },
                    set: { newValue in
                        step = .click(id: id, button: newValue, position: position)
                    }
                )) {
                    ForEach(MouseButton.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .fixedSize()

                Picker("", selection: Binding<PositionMode>(
                    get: { positionMode(for: position) },
                    set: { newValue in
                        let newPos: MacroStep.ClickPosition
                        switch newValue {
                        case .currentCursor: newPos = .currentCursor
                        case .fixed:
                            if case .fixed = position { newPos = position }
                            else { newPos = .fixed(x: 0, y: 0) }
                        }
                        step = .click(id: id, button: button, position: newPos)
                    }
                )) {
                    Text("At cursor").tag(PositionMode.currentCursor)
                    Text("Fixed").tag(PositionMode.fixed)
                }
                .labelsHidden()
                .fixedSize()

                if case .fixed(let x, let y) = position {
                    Text("(\(Int(x)), \(Int(y)))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button {
                        PositionPicker.pick { picked in
                            guard let point = picked else { return }
                            step = .click(id: id, button: button,
                                          position: .fixed(x: point.x, y: point.y))
                        }
                    } label: {
                        Image(systemName: "scope")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()
                    .help("Pick a screen position")
                }
            }
        }
    }

    private enum PositionMode { case currentCursor, fixed }

    private func positionMode(for pos: MacroStep.ClickPosition) -> PositionMode {
        switch pos {
        case .currentCursor: .currentCursor
        case .fixed:         .fixed
        }
    }
}

// MARK: - Key step

struct KeyStepEditor: View {
    @Binding var step: MacroStep

    var body: some View {
        if case .key(let id, let keyCode, let mods) = step {
            HotkeyRecorderField(hotkey: Binding<Hotkey?>(
                get: { Hotkey(keyCode: keyCode, modifiers: mods) },
                set: { newValue in
                    let combo = newValue ?? Hotkey(keyCode: keyCode, modifiers: mods)
                    step = .key(id: id, keyCode: combo.keyCode, modifiers: combo.modifiers)
                }
            ))
        }
    }
}

// MARK: - Wait step

struct WaitStepEditor: View {
    @Binding var step: MacroStep

    private enum Mode: String, CaseIterable { case fixed, random }

    var body: some View {
        if case .wait(let id, let duration) = step {
            HStack(spacing: 8) {
                Picker("", selection: Binding<Mode>(
                    get: { mode(for: duration) },
                    set: { newMode in
                        step = .wait(id: id, duration: switchMode(duration, to: newMode))
                    }
                )) {
                    Text("Fixed").tag(Mode.fixed)
                    Text("Random").tag(Mode.random)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)

                switch duration {
                case .fixed(let ms, let unit):
                    fixedFields(id: id, ms: ms, unit: unit)
                case .random(let lo, let hi, let unit):
                    randomFields(id: id, lo: lo, hi: hi, unit: unit)
                }
            }
        }
    }

    @ViewBuilder
    private func fixedFields(id: UUID, ms: Int, unit: MacroStep.DurationUnit) -> some View {
        NumberField(
            value: Binding<Int>(
                get: { displayValue(for: ms, unit: unit) },
                set: { newDisplay in
                    let newMs = newDisplay * unit.msPerUnit
                    step = .wait(id: id, duration: .fixed(milliseconds: newMs, unit: unit))
                }
            ),
            range: 1...1_000_000, step: 1, unit: nil, width: 70
        )
        unitPicker(current: unit) { newUnit in
            let preservedMs = convertPreserving(ms: ms, from: unit, to: newUnit)
            step = .wait(id: id, duration: .fixed(milliseconds: preservedMs, unit: newUnit))
        }
    }

    @ViewBuilder
    private func randomFields(id: UUID, lo: Int, hi: Int, unit: MacroStep.DurationUnit) -> some View {
        NumberField(
            value: Binding<Int>(
                get: { displayValue(for: lo, unit: unit) },
                set: { newDisplay in
                    let newMs = newDisplay * unit.msPerUnit
                    step = .wait(id: id, duration: .random(minMs: newMs, maxMs: hi, unit: unit))
                }
            ),
            range: 1...1_000_000, step: 1, unit: nil, width: 50
        )
        Text("to").font(.caption).foregroundStyle(.secondary)
        NumberField(
            value: Binding<Int>(
                get: { displayValue(for: hi, unit: unit) },
                set: { newDisplay in
                    let newMs = newDisplay * unit.msPerUnit
                    step = .wait(id: id, duration: .random(minMs: lo, maxMs: newMs, unit: unit))
                }
            ),
            range: 1...1_000_000, step: 1, unit: nil, width: 50
        )
        unitPicker(current: unit) { newUnit in
            let newLo = convertPreserving(ms: lo, from: unit, to: newUnit)
            let newHi = convertPreserving(ms: hi, from: unit, to: newUnit)
            step = .wait(id: id, duration: .random(minMs: newLo, maxMs: newHi, unit: newUnit))
        }
    }

    private func unitPicker(
        current: MacroStep.DurationUnit,
        onChange: @escaping (MacroStep.DurationUnit) -> Void
    ) -> some View {
        Picker("", selection: Binding<MacroStep.DurationUnit>(
            get: { current },
            set: { onChange($0) }
        )) {
            ForEach(MacroStep.DurationUnit.allCases) { unit in
                Text(unit.title).tag(unit)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    private func mode(for duration: MacroStep.WaitDuration) -> Mode {
        switch duration {
        case .fixed:  .fixed
        case .random: .random
        }
    }

    private func switchMode(
        _ duration: MacroStep.WaitDuration,
        to newMode: Mode
    ) -> MacroStep.WaitDuration {
        switch (duration, newMode) {
        case (.fixed(let ms, let unit), .random):
            return .random(minMs: ms, maxMs: ms * 2, unit: unit)
        case (.random(let lo, _, let unit), .fixed):
            return .fixed(milliseconds: lo, unit: unit)
        default:
            return duration
        }
    }

    private func displayValue(for ms: Int, unit: MacroStep.DurationUnit) -> Int {
        unit == .ms ? ms : max(0, ms / unit.msPerUnit)
    }

    private func convertPreserving(
        ms: Int,
        from old: MacroStep.DurationUnit,
        to new: MacroStep.DurationUnit
    ) -> Int {
        let display = displayValue(for: ms, unit: old)
        return display * new.msPerUnit
    }
}

// MARK: - Type step

struct TypeStepEditor: View {
    @Binding var step: MacroStep

    var body: some View {
        if case .type(let id, let text) = step {
            TextField("Text to type", text: Binding(
                get: { text },
                set: { newValue in
                    step = .type(id: id, text: newValue)
                }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 360)
        }
    }
}

// MARK: - Move step

struct MoveStepEditor: View {
    @Binding var step: MacroStep

    var body: some View {
        if case .move(let id, let x, let y, let ms) = step {
            HStack(spacing: 6) {
                Text("to")
                    .foregroundStyle(.secondary)
                NumberField(
                    value: Binding<Int>(
                        get: { Int(x) },
                        set: { step = .move(id: id, toX: CGFloat($0), toY: y, durationMs: ms) }
                    ),
                    range: 0...10_000, step: 1, unit: nil, width: 52
                )
                Text(",").foregroundStyle(.secondary)
                NumberField(
                    value: Binding<Int>(
                        get: { Int(y) },
                        set: { step = .move(id: id, toX: x, toY: CGFloat($0), durationMs: ms) }
                    ),
                    range: 0...10_000, step: 1, unit: nil, width: 52
                )
                Text("in").foregroundStyle(.secondary)
                NumberField(
                    value: Binding<Int>(
                        get: { ms },
                        set: { step = .move(id: id, toX: x, toY: y, durationMs: max(0, $0)) }
                    ),
                    range: 0...60_000, step: 10, unit: nil, width: 56
                )
                Text("ms").font(.caption).foregroundStyle(.secondary)

                Button {
                    PositionPicker.pick { picked in
                        guard let p = picked else { return }
                        step = .move(id: id, toX: p.x, toY: p.y, durationMs: ms)
                    }
                } label: {
                    Image(systemName: "scope")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
                .help("Pick a screen position")
            }
        }
    }
}
