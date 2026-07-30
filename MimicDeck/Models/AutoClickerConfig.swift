// Config for the simple autoclicker. Separate from Macro so a quick clicker
// needs no saved macro.

import CoreGraphics
import Foundation

nonisolated struct AutoClickerConfig: Codable, Hashable, Sendable {
    enum PositionMode: String, Codable, CaseIterable, Sendable {
        case currentCursor
        case fixed
    }

    enum IntervalMode: String, Codable, CaseIterable, Sendable {
        case fixed
        case random
    }

    enum TriggerMode: String, Codable, CaseIterable, Sendable {
        case toggle    // hotkey press toggles start/stop
        case hold      // hold hotkey to click, release to stop

        var title: String {
            switch self {
            case .toggle: "Toggle"
            case .hold:   "Hold"
            }
        }
    }

    var button: MouseButton
    var positionMode: PositionMode
    var fixedPosition: CGPoint?
    var intervalMode: IntervalMode
    var intervalMilliseconds: Int
    var intervalMinMilliseconds: Int
    var intervalMaxMilliseconds: Int

    // Mixable stop conditions. Whichever triggers first stops the clicker.
    var stopAfterClicksEnabled: Bool
    var stopAfterClicks: Int
    var stopAfterDurationEnabled: Bool
    var stopAfterDurationMilliseconds: Int
    var stopOnWindowChangeEnabled: Bool

    var triggerMode: TriggerMode
    var hotkey: Hotkey?

    static let defaults = AutoClickerConfig(
        button: .left,
        positionMode: .currentCursor,
        fixedPosition: nil,
        intervalMode: .fixed,
        intervalMilliseconds: 100,
        intervalMinMilliseconds: 50,
        intervalMaxMilliseconds: 200,
        stopAfterClicksEnabled: false,
        stopAfterClicks: 100,
        stopAfterDurationEnabled: false,
        stopAfterDurationMilliseconds: 5_000,
        stopOnWindowChangeEnabled: false,
        triggerMode: .toggle,
        hotkey: nil
    )

    /// Random needs min <= max, enabled limits need > 0, and any interval
    /// needs at least 1 ms. A 0 busy-spins the loop and Stop stops
    /// responding. The UI clamps, but an old prefs file can still carry one.
    var isValid: Bool {
        guard intervalMilliseconds >= 1 else { return false }
        if intervalMode == .random {
            guard intervalMinMilliseconds >= 1,
                  intervalMaxMilliseconds >= intervalMinMilliseconds else { return false }
        }
        if stopAfterClicksEnabled, stopAfterClicks <= 0 { return false }
        if stopAfterDurationEnabled, stopAfterDurationMilliseconds <= 0 { return false }
        return true
    }
}
