// Auto Clicker screen: trigger, button, interval, stop limits, run bar.
// Pure UI, everything stateful lives in AutoClickerRunner.

import AppKit
import SwiftUI

struct AutoClickerView: View {
    @Environment(AutoClickerRunner.self) private var runner

    /// The stop-limit rows carry a stepper and the last one does not, so
    /// without a shared height the gaps between them come out uneven.
    private static let limitRowHeight: CGFloat = 26

    private var isRunning: Bool { runner.isRunning }

    /// Per-field bindings onto the runner config, e.g. cfg.intervalMode.
    private var cfg: Binding<AutoClickerConfig> {
        Binding(get: { runner.config }, set: { runner.config = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                triggerCard
                clickCard
                intervalCard
                limitsCard
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: 760, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) { runBar }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backgroundGradient)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.06), Color.accentColor.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Auto Clicker")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("Pick a trigger, fine-tune the click, and start automating.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var triggerCard: some View {
        sectionCard(
            title: "Trigger",
            description: "How the autoclicker starts and stops."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Mode", selection: cfg.triggerMode) {
                    ForEach(AutoClickerConfig.TriggerMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
                .frame(maxWidth: .infinity, alignment: .center)

                row(label: "Hotkey",
                    help: "Pick any key combo. Works globally, even when MimicDeck isn't focused.") {
                    HotkeyRecorderField(hotkey: cfg.hotkey)
                }

                Text(triggerExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var clickCard: some View {
        sectionCard(
            title: "Click",
            description: "What kind of click to send and where."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                row(label: "Button",
                    help: "Which mouse button to press.") {
                    Picker("", selection: cfg.button) {
                        ForEach(MouseButton.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                row(label: "Position",
                    help: "Click wherever the cursor currently is, or always at a fixed screen point.") {
                    Picker("", selection: cfg.positionMode) {
                        Text("At cursor").tag(AutoClickerConfig.PositionMode.currentCursor)
                        Text("Fixed").tag(AutoClickerConfig.PositionMode.fixed)
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                if runner.config.positionMode == .fixed {
                    row(label: "Target",
                        help: "Pick a screen position. MimicDeck dims the screen, then captures the next click as the target.") {
                        HStack(spacing: 8) {
                            if let pos = runner.config.fixedPosition {
                                Text("(\(Int(pos.x)), \(Int(pos.y)))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not set")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Button {
                                PositionPicker.pick { picked in
                                    if let p = picked { runner.config.fixedPosition = p }
                                }
                            } label: {
                                Label("Pick…", systemImage: "scope")
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var intervalCard: some View {
        sectionCard(
            title: "Interval",
            description: "How long to wait between clicks. Lower values click faster."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Interval mode", selection: cfg.intervalMode) {
                    Text("Fixed").tag(AutoClickerConfig.IntervalMode.fixed)
                    Text("Random").tag(AutoClickerConfig.IntervalMode.random)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
                .frame(maxWidth: .infinity, alignment: .center)

                switch runner.config.intervalMode {
                case .fixed:
                    row(label: "Every",
                        help: "Wait this many milliseconds between each click.") {
                        NumberField(value: cfg.intervalMilliseconds,
                                    range: 1...60_000, step: 10, unit: "ms")
                    }
                case .random:
                    row(label: "Min",
                        help: "Lower bound of the random wait.") {
                        NumberField(value: cfg.intervalMinMilliseconds,
                                    range: 1...60_000, step: 10, unit: "ms")
                    }
                    row(label: "Max",
                        help: "Upper bound of the random wait. Each click picks a fresh value between Min and Max.") {
                        NumberField(value: cfg.intervalMaxMilliseconds,
                                    range: 1...60_000, step: 10, unit: "ms")
                    }
                }
            }
        }
    }

    private var limitsCard: some View {
        sectionCard(
            title: "Stop limits",
            description: "Optional. Any limit you hit first stops the clicker. With all off, it runs until you stop it manually."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                limitToggleRow(
                    title: "After a number of clicks",
                    help: "Stops automatically once this many clicks have been sent.",
                    enabled: cfg.stopAfterClicksEnabled,
                    field: {
                        NumberField(value: cfg.stopAfterClicks,
                                    range: 1...10_000_000, step: 10, unit: "clicks", width: 100)
                    }
                )

                limitToggleRow(
                    title: "After a time limit",
                    help: "Stops automatically once this much time has elapsed since Start.",
                    enabled: cfg.stopAfterDurationEnabled,
                    field: {
                        NumberField(value: cfg.stopAfterDurationMilliseconds,
                                    range: 100...3_600_000, step: 500, unit: "ms", width: 100)
                    }
                )

                Toggle(isOn: cfg.stopOnWindowChangeEnabled) {
                    HStack(spacing: 6) {
                        Text("On window change")
                        HelpHint(text: "Stops automatically as soon as the frontmost app changes (e.g. you Cmd-Tab away).")
                    }
                }
                .toggleStyle(.checkbox)
                .frame(height: Self.limitRowHeight, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var runBar: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                runner.toggle()
            } label: {
                Label(isRunning ? "Stop" : "Start",
                      systemImage: isRunning ? "stop.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 90)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isRunning ? .red : .accentColor)
            .disabled(!runner.config.isValid)
            .keyboardShortcut(.defaultAction)

            VStack(alignment: .leading, spacing: 1) {
                Text(isRunning ? "Running" : "Ready")
                    .font(.subheadline.weight(.semibold))
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRunning {
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

    // MARK: - Helpers

    private var triggerExplanation: String {
        switch runner.config.triggerMode {
        case .toggle:
            return "Press the hotkey from anywhere to start the clicker. Press it again to stop."
        case .hold:
            return "Hold the hotkey to keep clicking. Release to stop."
        }
    }

    private var statusSubtitle: String {
        if isRunning {
            return "\(runner.clicksFired) clicks sent"
        }
        if runner.clicksFired > 0 {
            return "Last run: \(runner.clicksFired) clicks"
        }
        return "Set up the options above, then Start."
    }

    private func sectionCard<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SectionCard(title: title, description: description, content: content)
    }

    private func row<Content: View>(
        label: String,
        help: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        LabeledRow(label: label, help: help, content: content)
    }

    private func limitToggleRow<Field: View>(
        title: String,
        help: String,
        enabled: Binding<Bool>,
        @ViewBuilder field: () -> Field
    ) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: enabled) {
                HStack(spacing: 6) {
                    Text(title)
                    HelpHint(text: help)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            field()
                .disabled(!enabled.wrappedValue)
                .opacity(enabled.wrappedValue ? 1 : 0.5)
        }
        .frame(height: Self.limitRowHeight)
    }
}
