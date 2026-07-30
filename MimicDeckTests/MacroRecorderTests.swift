// The typed-text merge pass. Live event capture can't run from a test
// process, so we feed the post-processing step synthesized arrays.

import Foundation
import Testing
@testable import MimicDeck

@Suite("MacroRecorder.mergeAdjacentTypedText")
struct MacroRecorderMergeTests {
    @Test("Three consecutive .type steps merge into one")
    func mergesConsecutiveTypes() {
        let steps: [MacroStep] = [
            .type("a"),
            .type("b"),
            .type("c"),
        ]
        let merged = MacroRecorder.mergeAdjacentTypedText(steps)
        #expect(merged.count == 1)
        if case .type(_, let text) = merged[0] {
            #expect(text == "abc")
        } else {
            Issue.record("Expected a .type step")
        }
    }

    @Test("Short waits between .type steps are dropped")
    func dropsShortTypingPauses() {
        let steps: [MacroStep] = [
            .type("h"),
            .wait(milliseconds: 80),
            .type("e"),
            .wait(milliseconds: 95),
            .type("y"),
        ]
        let merged = MacroRecorder.mergeAdjacentTypedText(steps)
        #expect(merged.count == 1)
        if case .type(_, let text) = merged[0] {
            #expect(text == "hey")
        }
    }

    @Test("Wait at or above the threshold stops the merge")
    func longWaitBreaksMerge() {
        let steps: [MacroStep] = [
            .type("a"),
            .wait(milliseconds: 200),
            .type("b"),
            .wait(milliseconds: 1500),
            .type("c"),
        ]
        let merged = MacroRecorder.mergeAdjacentTypedText(steps)
        #expect(merged.count == 3) // "ab", wait 1500, "c"
        if case .type(_, let firstText) = merged[0] {
            #expect(firstText == "ab")
        }
        if case .wait = merged[1] {} else { Issue.record("Expected wait in the middle") }
        if case .type(_, let lastText) = merged[2] {
            #expect(lastText == "c")
        }
    }

    @Test("Non-type steps are preserved untouched")
    func preservesOtherSteps() {
        let steps: [MacroStep] = [
            .click(.left),
            .type("y"),
            .key(0x24), // Return, modeled as .key
            .type("ok"),
        ]
        let merged = MacroRecorder.mergeAdjacentTypedText(steps)
        #expect(merged.count == 4)
        if case .click = merged[0] {} else { Issue.record("click lost") }
        if case .type(_, let t1) = merged[1] { #expect(t1 == "y") }
        if case .key = merged[2] {} else { Issue.record("key lost") }
        if case .type(_, let t2) = merged[3] { #expect(t2 == "ok") }
    }

    @Test("Random waits are never collapsed")
    func randomWaitsNotMerged() {
        let steps: [MacroStep] = [
            .type("a"),
            .waitRandom(minMs: 50, maxMs: 80),
            .type("b"),
        ]
        let merged = MacroRecorder.mergeAdjacentTypedText(steps)
        // Random wait is a deliberate pause, so the run breaks: three steps.
        #expect(merged.count == 3)
    }
}
