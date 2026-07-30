// Codable round-trips and factory helpers for MacroStep.

import Foundation
import Testing
@testable import MimicDeck

@Suite("MacroStep")
struct MacroStepTests {
    private func roundTrip(_ step: MacroStep) throws -> MacroStep {
        let data = try JSONEncoder().encode(step)
        return try JSONDecoder().decode(MacroStep.self, from: data)
    }

    @Test("Click step at cursor round-trips through JSON")
    func clickCursorRoundTrip() throws {
        let original = MacroStep.click(.left)
        #expect(try roundTrip(original) == original)
    }

    @Test("Click step at fixed point round-trips")
    func clickFixedRoundTrip() throws {
        let original = MacroStep.click(.right, at: .fixed(x: 100, y: 200))
        #expect(try roundTrip(original) == original)
    }

    @Test("Key step round-trips with modifiers")
    func keyRoundTrip() throws {
        let original = MacroStep.key(0x12, modifiers: [.command, .shift])
        #expect(try roundTrip(original) == original)
    }

    @Test("Wait step clamps negative durations to 0")
    func waitClamping() {
        let step = MacroStep.wait(milliseconds: -50)
        if case .wait(_, let duration) = step {
            #expect(duration.sampledMilliseconds == 0)
        } else {
            Issue.record("Expected .wait, got \(step)")
        }
    }

    @Test("Random wait samples within range")
    func waitRandomRange() {
        let step = MacroStep.waitRandom(minMs: 100, maxMs: 200)
        if case .wait(_, let duration) = step {
            for _ in 0..<10 {
                let sample = duration.sampledMilliseconds
                #expect(sample >= 100 && sample <= 200)
            }
        }
    }

    @Test("Move step round-trips with coordinates and duration")
    func moveRoundTrip() throws {
        let original = MacroStep.move(toX: 250.5, toY: 480.25, durationMs: 200)
        #expect(try roundTrip(original) == original)
    }

    @Test("Move step clamps negative duration")
    func moveClampDuration() {
        let step = MacroStep.move(toX: 10, toY: 10, durationMs: -50)
        if case .move(_, _, _, let ms) = step {
            #expect(ms == 0)
        } else {
            Issue.record("Expected .move")
        }
    }

    @Test("Wait step round-trips")
    func waitRoundTrip() throws {
        let original = MacroStep.wait(milliseconds: 250)
        #expect(try roundTrip(original) == original)
    }

    @Test("Factory methods generate unique IDs")
    func uniqueIDs() {
        let a = MacroStep.click(.left)
        let b = MacroStep.click(.left)
        #expect(a.id != b.id)
    }

    @Test("Summary text reflects step contents")
    func summary() {
        #expect(MacroStep.click(.left).summary.contains("Left"))
        #expect(MacroStep.wait(milliseconds: 500).summary == "Wait 500 ms")
    }
}
