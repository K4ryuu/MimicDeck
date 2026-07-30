// Validation and codable tests for AutoClickerConfig.

import Foundation
import Testing
@testable import MimicDeck

@Suite("AutoClickerConfig")
struct AutoClickerConfigTests {
    @Test("Defaults are valid")
    func defaultsValid() {
        #expect(AutoClickerConfig.defaults.isValid)
    }

    @Test("Random interval requires min <= max")
    func randomIntervalValidation() {
        var config = AutoClickerConfig.defaults
        config.intervalMode = .random
        config.intervalMinMilliseconds = 200
        config.intervalMaxMilliseconds = 100
        #expect(!config.isValid)
        config.intervalMaxMilliseconds = 300
        #expect(config.isValid)
    }

    @Test("Negative fixed interval is rejected")
    func negativeIntervalRejected() {
        var config = AutoClickerConfig.defaults
        config.intervalMilliseconds = -10
        #expect(!config.isValid)
    }

    @Test("Zero interval is rejected: it would busy-spin the click loop")
    func zeroIntervalRejected() {
        var config = AutoClickerConfig.defaults
        config.intervalMilliseconds = 0
        #expect(!config.isValid)

        var random = AutoClickerConfig.defaults
        random.intervalMode = .random
        random.intervalMinMilliseconds = 0
        random.intervalMaxMilliseconds = 100
        #expect(!random.isValid)
    }

    @Test("Stop-after-clicks limit must be positive when enabled")
    func stopAfterClicksPositive() {
        var config = AutoClickerConfig.defaults
        config.stopAfterClicksEnabled = true
        config.stopAfterClicks = 0
        #expect(!config.isValid)
        config.stopAfterClicks = 5
        #expect(config.isValid)
    }

    @Test("Stop-after-duration limit must be positive when enabled")
    func stopAfterDurationPositive() {
        var config = AutoClickerConfig.defaults
        config.stopAfterDurationEnabled = true
        config.stopAfterDurationMilliseconds = 0
        #expect(!config.isValid)
        config.stopAfterDurationMilliseconds = 1000
        #expect(config.isValid)
    }

    @Test("Disabled limits don't fail validation regardless of value")
    func disabledLimitsIgnored() {
        var config = AutoClickerConfig.defaults
        config.stopAfterClicks = 0
        config.stopAfterDurationMilliseconds = 0
        #expect(config.isValid)
    }

    @Test("Round-trips through JSON")
    func codableRoundTrip() throws {
        let original = AutoClickerConfig.defaults
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(AutoClickerConfig.self, from: data)
        #expect(restored == original)
    }
}
