// Interval sampling for the click loop. A 0 here busy-spins the main actor
// and Stop stops responding, so the 1 ms floor is load-bearing.

import Testing
@testable import MimicDeck

@Suite("AutoClickerRunner.nextIntervalMs")
struct AutoClickerRunnerIntervalTests {
    private func config(
        mode: AutoClickerConfig.IntervalMode,
        fixed: Int = 100,
        min: Int = 50,
        max: Int = 200
    ) -> AutoClickerConfig {
        var config = AutoClickerConfig.defaults
        config.intervalMode = mode
        config.intervalMilliseconds = fixed
        config.intervalMinMilliseconds = min
        config.intervalMaxMilliseconds = max
        return config
    }

    @Test("Fixed interval is returned as-is")
    func fixedPassesThrough() {
        #expect(AutoClickerRunner.nextIntervalMs(for: config(mode: .fixed, fixed: 250)) == 250)
    }

    @Test("A stored zero interval is clamped to 1 ms")
    func zeroFixedIsClamped() {
        #expect(AutoClickerRunner.nextIntervalMs(for: config(mode: .fixed, fixed: 0)) == 1)
    }

    @Test("A negative interval is clamped to 1 ms")
    func negativeFixedIsClamped() {
        #expect(AutoClickerRunner.nextIntervalMs(for: config(mode: .fixed, fixed: -500)) == 1)
    }

    @Test("Random interval stays inside the requested bounds")
    func randomWithinBounds() {
        let config = config(mode: .random, min: 40, max: 60)
        for _ in 0..<200 {
            let sampled = AutoClickerRunner.nextIntervalMs(for: config)
            #expect(sampled >= 40)
            #expect(sampled <= 60)
        }
    }

    @Test("Inverted random bounds are tolerated, not crashed on")
    func invertedRandomBounds() {
        let config = config(mode: .random, min: 300, max: 100)
        for _ in 0..<50 {
            let sampled = AutoClickerRunner.nextIntervalMs(for: config)
            #expect(sampled >= 100)
            #expect(sampled <= 300)
        }
    }

    @Test("Random mode never samples zero")
    func randomNeverZero() {
        let config = config(mode: .random, min: 0, max: 0)
        for _ in 0..<50 {
            #expect(AutoClickerRunner.nextIntervalMs(for: config) >= 1)
        }
    }
}
