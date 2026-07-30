// Step iteration, loop counting and stop semantics, against fake executors.

import Foundation
import Testing
@testable import MimicDeck

/// Records steps, returns immediately. For assertions about the end result.
@MainActor
final class RecordingExecutor: StepExecutor {
    private(set) var calls: [MacroStep] = []

    func execute(_ step: MacroStep) async {
        calls.append(step)
    }
}

/// Records steps and parks inside `execute` until the test releases it.
///
/// The engine hands `.wait` steps to the executor instead of sleeping itself,
/// so a fake that returns immediately finishes a "slow" macro before the test
/// can look. Sleeping in the fake just swaps that for a race, since cases run
/// concurrently on the main actor. Parking needs no timing at all.
@MainActor
final class GatedExecutor: StepExecutor {
    private(set) var calls: [MacroStep] = []

    private var parked: CheckedContinuation<Void, Never>?
    private var arrival: CheckedContinuation<Void, Never>?

    func execute(_ step: MacroStep) async {
        calls.append(step)
        // The waiter resumes on the main actor after we park, so it always
        // sees the parked state.
        arrival?.resume()
        arrival = nil
        await withCheckedContinuation { parked = $0 }
    }

    /// Waits for a step to park.
    func waitUntilParked() async {
        guard parked == nil else { return }
        await withCheckedContinuation { arrival = $0 }
    }

    /// Let the parked step finish.
    func releaseStep() {
        parked?.resume()
        parked = nil
    }

    /// Release `count` steps, waiting for each.
    func releaseSteps(_ count: Int) async {
        for _ in 0..<count {
            await waitUntilParked()
            releaseStep()
        }
    }
}

@Suite("MacroEngine")
@MainActor
struct MacroEngineTests {
    @Test("Empty macro is a no-op and leaves state idle")
    func emptyMacro() async {
        let executor = RecordingExecutor()
        let engine = MacroEngine(executor: executor)
        await engine.run(Macro(name: "Empty"))
        #expect(executor.calls.isEmpty)
        #expect(engine.state == .idle)
    }

    @Test("All steps fire in order for a single iteration")
    func stepsRunInOrder() async {
        let executor = RecordingExecutor()
        let engine = MacroEngine(executor: executor)
        let macro = Macro(name: "Run", steps: [
            .click(.left),
            .wait(milliseconds: 0),
            .key(0x31)
        ])
        await engine.run(macro)
        #expect(executor.calls.count == 3)
        if case .click = executor.calls[0] {} else { Issue.record("Expected click first") }
        if case .wait = executor.calls[1]  {} else { Issue.record("Expected wait second") }
        if case .key = executor.calls[2]   {} else { Issue.record("Expected key third") }
    }

    @Test("loopCount > 1 runs the macro N times")
    func loopCountThree() async {
        let executor = RecordingExecutor()
        let engine = MacroEngine(executor: executor)
        let macro = Macro(name: "Loop", steps: [.click(.left)], loopCount: 3)
        await engine.run(macro)
        #expect(executor.calls.count == 3)
    }

    @Test("isRunning reflects active execution")
    func isRunningFlag() async {
        let executor = GatedExecutor()
        let engine = MacroEngine(executor: executor)
        #expect(!engine.isRunning)

        let task = Task { await engine.run(Macro(name: "X", steps: [.click(.left)])) }
        await executor.waitUntilParked()
        #expect(engine.isRunning)

        executor.releaseStep()
        await task.value
        #expect(!engine.isRunning)
    }

    @Test("loopCount 0 loops until stopped")
    func infiniteLoopNeedsStop() async {
        let executor = GatedExecutor()
        let engine = MacroEngine(executor: executor)
        let macro = Macro(name: "Forever", steps: [.click(.left)], loopCount: 0)

        let task = Task { await engine.run(macro) }
        // Three passes over a one-step macro. A bounded loop would have
        // stopped after the first.
        await executor.releaseSteps(3)

        await executor.waitUntilParked()
        #expect(engine.isRunning)
        engine.stop()
        executor.releaseStep()
        await task.value

        #expect(engine.state == .idle)
        #expect(executor.calls.count >= 4)
    }

    @Test("Stop interrupts mid-execution")
    func stopInterrupts() async {
        let executor = GatedExecutor()
        let engine = MacroEngine(executor: executor)
        let macro = Macro(name: "Slow", steps: [.click(.left)], loopCount: 50)

        let task = Task { await engine.run(macro) }
        await executor.waitUntilParked()
        engine.stop()
        executor.releaseStep()
        await task.value

        #expect(engine.state == .idle)
        #expect(executor.calls.count < 50)
    }

    @Test("A second run is ignored while one is already in flight")
    func concurrentRunIgnored() async {
        let executor = GatedExecutor()
        let engine = MacroEngine(executor: executor)
        let macro = Macro(name: "Busy", steps: [.click(.left)], loopCount: 3)

        let task = Task { await engine.run(macro) }
        await executor.waitUntilParked()

        // Must return straight away, not queue up or interleave.
        await engine.run(Macro(name: "Intruder", steps: [.key(0x31)]))

        await executor.releaseSteps(3)
        await task.value

        #expect(executor.calls.count == 3)
        #expect(executor.calls.allSatisfy { if case .click = $0 { true } else { false } })
    }
}
