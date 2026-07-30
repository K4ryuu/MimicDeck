// Editor for one macro: hero, Info / Trigger / Steps cards, sticky run bar.

import AppKit
import SwiftUI

struct MacroEditorView: View {
    @Environment(MacroStore.self) private var store
    @Environment(MacroEngine.self) private var engine
    @Environment(MacroRecorder.self) private var recorder

    let macroID: UUID

    @State private var showingSymbolPicker: Bool = false
    @State private var hoveredSymbol: String?
    @State private var confirmingClearMacroID: UUID?

    private var macro: Macro? {
        store.macros.first(where: { $0.id == macroID })
    }

    var body: some View {
        Group {
            if let macro {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        hero(for: macro)
                        infoCard(for: macro)
                        triggerCard(for: macro)
                        stepsCard(for: macro)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .frame(maxWidth: 760, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaInset(edge: .bottom) { runBar(for: macro) }
                .background(backgroundGradient)
            } else {
                ContentUnavailableView("Select a macro", systemImage: "square.dashed")
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.06), Color.accentColor.opacity(0.0)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Sections

    private func hero(for macro: Macro) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                showingSymbolPicker = true
            } label: {
                Image(systemName: macro.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.separator.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Change icon")
            .popover(isPresented: $showingSymbolPicker, arrowEdge: .bottom) {
                symbolGrid(for: macro)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(macro.name)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("\(macro.steps.count) step\(macro.steps.count == 1 ? "" : "s") · \(loopLabel(for: macro))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoCard(for macro: Macro) -> some View {
        SectionCard(
            title: "Info",
            description: "Name your macro and choose how many times it loops."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledRow(label: "Name",
                           help: "Shown in the macro list and toolbar.") {
                    TextField("Macro name", text: Binding(
                        get: { macro.name },
                        set: { newValue in
                            var copy = macro
                            copy.name = newValue
                            store.update(copy)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                }
                LabeledRow(label: "Loops",
                           help: "How many times to play the whole step list. 0 means infinite.") {
                    NumberField(value: Binding(
                        get: { macro.loopCount },
                        set: { newValue in
                            var copy = macro
                            copy.loopCount = max(0, newValue)
                            store.update(copy)
                        }
                    ), range: 0...9999, step: 1, unit: macro.loopCount == 0 ? "(infinite)" : "times", width: 80)
                }
            }
        }
    }

    private func symbolGrid(for macro: Macro) -> some View {
        let columns = Array(repeating: GridItem(.fixed(40), spacing: 8), count: 6)
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Macro.availableSymbols, id: \.self) { symbol in
                    symbolCell(macro: macro, symbol: symbol)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 320, height: 280)
    }

    private func symbolCell(macro: Macro, symbol: String) -> some View {
        let isSelected = symbol == macro.symbol
        let isHovered = hoveredSymbol == symbol
        return Button {
            var copy = macro
            copy.symbol = symbol
            store.update(copy)
            showingSymbolPicker = false
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .frame(width: 40, height: 40)
                    .background(symbolBackground(isSelected: isSelected, isHovered: isHovered),
                                in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.5) : Color.clear,
                                lineWidth: 1
                            )
                    )

                if isHovered && !isSelected {
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint, .background)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(symbol)
        .onHover { hovering in
            if hovering {
                hoveredSymbol = symbol
            } else if hoveredSymbol == symbol {
                hoveredSymbol = nil
            }
        }
    }

    private func symbolBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        if isHovered  { return Color.secondary.opacity(0.18) }
        return .clear
    }

    private func triggerCard(for macro: Macro) -> some View {
        SectionCard(
            title: "Trigger",
            description: "Optionally restrict where it runs and assign a hotkey."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledRow(label: "Window",
                           help: "If set, the macro pauses automatically when this app is not frontmost.") {
                    WindowPickerField(filter: Binding(
                        get: { macro.windowFilter },
                        set: { newValue in
                            var copy = macro
                            copy.windowFilter = newValue
                            store.update(copy)
                        }
                    ))
                }
                LabeledRow(label: "Hotkey",
                           help: "Press anywhere to start or stop the macro. Works globally.") {
                    HotkeyRecorderField(hotkey: Binding(
                        get: { macro.hotkey },
                        set: { newValue in
                            var copy = macro
                            copy.hotkey = newValue
                            store.update(copy)
                        }
                    ))
                }
            }
        }
    }

    private func stepsCard(for macro: Macro) -> some View {
        SectionCard(
            title: "Steps",
            description: "Build the sequence step by step, or record it live."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                stepsHeader(for: macro)
                if recorder.isRecording {
                    recordingBanner
                } else if let failure = recorder.startFailure {
                    recorderFailureBanner(failure)
                }
                stepsList(for: macro)
                stepAdders(for: macro)
            }
        }
    }

    /// Captured steps are held until stop() so the editor does not rebuild the
    /// whole list on every keystroke. Without saying so, the empty list during
    /// a recording looks like nothing is being captured.
    private func recorderFailureBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Recording could not start")
                    .font(.callout.weight(.medium))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    private var recordingBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "record.circle")
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating)
            VStack(alignment: .leading, spacing: 2) {
                Text("Recording")
                    .font(.callout.weight(.medium))
                Text("Your clicks and keystrokes are being captured. The steps appear in the list once you stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
        )
    }

    private func stepsHeader(for macro: Macro) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleRecording(for: macro)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                    Text(recorder.isRecording ? "Stop recording" : "Record")
                    Text("⇧⌘R")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.bordered)
            .tint(recorder.isRecording ? .red : .accentColor)
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .help(recorder.isRecording ? "Stop recording (⇧⌘R)" : "Start recording (⇧⌘R)")

            Spacer()

            if !macro.steps.isEmpty {
                Button("Clear all", role: .destructive) {
                    confirmingClearMacroID = macro.id
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            "Remove all steps from this macro?",
            isPresented: Binding(
                get: { confirmingClearMacroID != nil },
                set: { if !$0 { confirmingClearMacroID = nil } }
            )
        ) {
            Button("Clear all steps", role: .destructive) {
                guard let id = confirmingClearMacroID,
                      var copy = store.macros.first(where: { $0.id == id }) else { return }
                copy.steps.removeAll()
                store.update(copy)
                confirmingClearMacroID = nil
            }
            Button("Cancel", role: .cancel) {
                confirmingClearMacroID = nil
            }
        } message: {
            Text("This empties the step list. The macro itself is kept.")
        }
    }

    private func stepsList(for macro: Macro) -> some View {
        Group {
            if macro.steps.isEmpty {
                emptyStepsState
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(Array(macro.steps.enumerated()), id: \.element.id) { index, step in
                        stepRow(macro: macro, index: index, step: step)
                    }
                }
            }
        }
    }

    private var emptyStepsState: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet.indent")
                .foregroundStyle(.tertiary)
            Text("No steps yet. Use Record or the buttons below.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func stepRow(macro: Macro, index: Int, step: MacroStep) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Image(systemName: stepIcon(step))
                .foregroundStyle(.tint)
                .frame(width: 18)

            stepEditor(macro: macro, index: index, step: step)

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                Button {
                    moveStep(in: macro, from: index, to: index - 1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(index == 0)
                .help("Move up")

                Button {
                    moveStep(in: macro, from: index, to: index + 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(index == macro.steps.count - 1)
                .help("Move down")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption.weight(.semibold))

            Button {
                duplicateStep(in: macro, at: index)
            } label: {
                Image(systemName: "plus.square.on.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Duplicate step")

            Button {
                var copy = macro
                copy.steps.remove(at: index)
                store.update(copy)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove step")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func stepEditor(macro: Macro, index: Int, step: MacroStep) -> some View {
        let binding = Binding<MacroStep>(
            get: { step },
            set: { newStep in
                var copy = macro
                guard copy.steps.indices.contains(index) else { return }
                copy.steps[index] = newStep
                store.update(copy)
            }
        )
        switch step {
        case .click: ClickStepEditor(step: binding)
        case .key:   KeyStepEditor(step: binding)
        case .wait:  WaitStepEditor(step: binding)
        case .type:  TypeStepEditor(step: binding)
        case .move:  MoveStepEditor(step: binding)
        }
    }

    private func stepIcon(_ step: MacroStep) -> String {
        switch step {
        case .click:  return "cursorarrow.click"
        case .key:    return "keyboard"
        case .wait:   return "hourglass"
        case .type:   return "text.cursor"
        case .move:   return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    private func duplicateStep(in macro: Macro, at index: Int) {
        guard macro.steps.indices.contains(index) else { return }
        var copy = macro
        copy.steps.insert(macro.steps[index].duplicated(), at: index + 1)
        store.update(copy)
    }

    private func moveStep(in macro: Macro, from: Int, to: Int) {
        guard macro.steps.indices.contains(from),
              to >= 0, to < macro.steps.count, from != to else { return }
        var copy = macro
        let step = copy.steps.remove(at: from)
        copy.steps.insert(step, at: to)
        store.update(copy)
    }

    private func stepAdders(for macro: Macro) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                addClickButton(for: macro)
                addKeyButton(for: macro)
                addWaitButton(for: macro)
            }
            HStack(spacing: 8) {
                addTypeButton(for: macro)
                addMoveButton(for: macro)
            }
        }
        .padding(.top, 4)
    }

    /// Hand-drawn button shell. Native Menu/Button refuses to fill a
    /// flexible container even with frame(maxWidth: .infinity).
    private func adderShell<Trailing: View>(
        label: String,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(label)
            Spacer(minLength: 0)
            trailing()
                .foregroundStyle(.tertiary)
                .imageScale(.small)
        }
        .font(.body)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func addClickButton(for macro: Macro) -> some View {
        Button {
            addStep(.click(.left), to: macro)
        } label: {
            adderShell(label: "Add click", systemImage: "cursorarrow.click")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func addKeyButton(for macro: Macro) -> some View {
        Button {
            // 0x31 = Space. Neutral default, the row editor changes it.
            addStep(.key(0x31), to: macro)
        } label: {
            adderShell(label: "Add key", systemImage: "keyboard")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func addWaitButton(for macro: Macro) -> some View {
        Button {
            addStep(.wait(milliseconds: 500), to: macro)
        } label: {
            adderShell(label: "Add wait", systemImage: "hourglass")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func addTypeButton(for macro: Macro) -> some View {
        Button {
            addStep(.type(""), to: macro)
        } label: {
            adderShell(label: "Add type text", systemImage: "text.cursor")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func addMoveButton(for macro: Macro) -> some View {
        Button {
            let here = EventTapService.currentCursorPosition()
            addStep(.move(toX: here.x, toY: here.y, durationMs: 200), to: macro)
        } label: {
            adderShell(label: "Add move", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
        }
        .buttonStyle(.plain)
    }

    private func runBar(for macro: Macro) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                if engine.isRunning {
                    engine.stop()
                } else {
                    Task { await engine.run(macro) }
                }
            } label: {
                Label(engine.isRunning ? "Stop" : "Run",
                      systemImage: engine.isRunning ? "stop.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 90)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(engine.isRunning ? .red : .accentColor)
            .disabled(macro.steps.isEmpty)
            .keyboardShortcut(.defaultAction)

            VStack(alignment: .leading, spacing: 1) {
                Text(engineStatusTitle)
                    .font(.subheadline.weight(.semibold))
                Text(engineStatusSubtitle(for: macro))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if engine.isRunning {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Status helpers

    private var engineStatusTitle: String {
        switch engine.state {
        case .idle:     return "Idle"
        case .running:  return "Running"
        case .paused:   return "Paused"
        case .stopping: return "Stopping…"
        }
    }

    private func engineStatusSubtitle(for macro: Macro) -> String {
        switch engine.state {
        case .running(_, let step, let iter):
            return "Step \(step + 1) of \(macro.steps.count) · iteration \(iter)"
        case .paused(_, _, _):
            return "Waiting for \(macro.windowFilter?.displayName ?? "target") to be frontmost"
        default:
            return "\(macro.steps.count) step\(macro.steps.count == 1 ? "" : "s") ready"
        }
    }

    private func loopLabel(for macro: Macro) -> String {
        macro.loopCount == 0 ? "loops forever" : "loops \(macro.loopCount)×"
    }

    // MARK: - Mutations

    private func addStep(_ step: MacroStep, to macro: Macro) {
        var copy = macro
        copy.steps.append(step)
        store.update(copy)
    }

    private func toggleRecording(for macro: Macro) {
        if recorder.isRecording {
            let captured = recorder.stop()
            var copy = macro
            copy.steps.append(contentsOf: captured)
            store.update(copy)
        } else {
            recorder.start()
        }
    }
}
