// Runs a macro step by step: loop count, window-filter pause/resume, clean
// cancel on stop. Dispatch goes through StepExecutor so tests can fake it.
//
// idle -> running -> (paused | stopping) -> idle.

import Foundation
import Observation
import os

@MainActor
@Observable
final class MacroEngine {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Engine")

    enum State: Equatable {
        case idle
        case running(macroID: UUID, step: Int, iteration: Int)
        case paused(macroID: UUID, step: Int, iteration: Int)
        case stopping
    }

    private(set) var state: State = .idle

    var isRunning: Bool {
        if case .idle = state { return false }
        return true
    }

    private let executor: any StepExecutor
    private let watcher: WindowWatcher?
    private var task: Task<Void, Never>?

    init(executor: any StepExecutor, watcher: WindowWatcher? = nil) {
        self.executor = executor
        self.watcher = watcher
    }

    func run(_ macro: Macro) async {
        guard !isRunning else {
            Self.log.info("run() ignored: engine already running")
            return
        }
        guard !macro.steps.isEmpty else {
            Self.log.info("run() ignored: macro has no steps")
            return
        }
        Self.log.info("Starting macro \(macro.name, privacy: .public)")
        task?.cancel()
        task = Task { [weak self] in
            await self?.runLoop(macro)
        }
        await task?.value
    }

    func stop() {
        guard isRunning else { return }
        Self.log.info("Stop requested")
        state = .stopping
        task?.cancel()
    }

    private func runLoop(_ macro: Macro) async {
        let infinite = macro.loopCount == 0
        var iteration = 0
        defer {
            state = .idle
            Self.log.info("Macro \(macro.name, privacy: .public) finished after \(iteration, privacy: .public) iterations")
        }

        // Throttle state writes. SwiftUI re-renders the run bar on every
        // change and a fast macro hits steps 1000+ times a second. First
        // step always publishes, then ~30 fps.
        var lastPublished: ContinuousClock.Instant? = nil
        let publishInterval: Duration = .milliseconds(33)

        while infinite || iteration < macro.loopCount {
            iteration += 1
            for (index, step) in macro.steps.enumerated() {
                if Task.isCancelled || state == .stopping { return }
                await waitForWindowMatchIfNeeded(macro: macro, step: index, iteration: iteration)
                if Task.isCancelled || state == .stopping { return }

                let now = ContinuousClock.now
                if lastPublished == nil || now - lastPublished! >= publishInterval {
                    state = .running(macroID: macro.id, step: index, iteration: iteration)
                    lastPublished = now
                }

                await executor.execute(step)
            }
        }
    }

    private func waitForWindowMatchIfNeeded(macro: Macro, step: Int, iteration: Int) async {
        guard let filter = macro.windowFilter, let watcher else { return }
        if filter.allows(frontmostBundleIdentifier: watcher.frontmostBundleIdentifier) { return }

        state = .paused(macroID: macro.id, step: step, iteration: iteration)
        Self.log.info("Paused, waiting for \(filter.displayName, privacy: .public)")
        while !Task.isCancelled && state != .stopping {
            if filter.allows(frontmostBundleIdentifier: watcher.frontmostBundleIdentifier) { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}
