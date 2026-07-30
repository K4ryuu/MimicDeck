// Config, global hotkey and the click loop for the simple autoclicker.
//
// Lives outside the view on purpose. When AutoClickerView owned the loop,
// switching sidebar sections killed the view while the Task kept clicking,
// with no UI left to stop it.

import AppKit
import CoreGraphics
import Foundation
import Observation
import os

@MainActor
@Observable
final class AutoClickerRunner {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Runner")
    private static let configDefaultsKey = "AutoClickerConfig.v1"

    /// Persists on every change, re-binds the hotkey when the trigger moves.
    var config: AutoClickerConfig {
        didSet {
            guard config != oldValue else { return }
            persistConfig()
            if config.hotkey != oldValue.hotkey || config.triggerMode != oldValue.triggerMode {
                syncHotkeyRegistration()
            }
        }
    }

    private(set) var isRunning: Bool = false
    private(set) var clicksFired: Int = 0

    private let executor: EventTapService
    private let watcher: WindowWatcher
    private let hotkeys: HotkeyService

    private var loopTask: Task<Void, Never>?
    /// Bumped on start and stop. A finishing loop only clears state if its
    /// generation is still current, otherwise a fast stop-start orphans the
    /// new task and the clicker runs with nothing able to stop it.
    private var runGeneration: Int = 0
    private var hotkeyToken: UInt32?

    init(
        executor: EventTapService,
        watcher: WindowWatcher,
        hotkeys: HotkeyService,
        emergency: EmergencyStopService
    ) {
        self.executor = executor
        self.watcher = watcher
        self.hotkeys = hotkeys
        self.config = Self.loadConfig()

        emergency.register(
            isActive: { [weak self] in self?.isRunning ?? false },
            stop:     { [weak self] in self?.stop() }
        )
        syncHotkeyRegistration()
    }

    // MARK: - Run lifecycle

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard !isRunning, config.isValid else { return }
        clicksFired = 0
        isRunning = true
        runGeneration += 1
        let generation = runGeneration
        let captured = config

        let ownBundleID = Bundle.main.bundleIdentifier

        Self.log.info("Autoclicker started")
        loopTask = Task { [weak self] in
            guard let self else { return }
            var fired = 0
            let started = ContinuousClock.now

            // Hitting Start means we are frontmost, so we cannot be the
            // baseline. Latch the first other app instead.
            var windowBaseline = self.watcher.frontmostBundleIdentifier == ownBundleID
                ? nil
                : self.watcher.frontmostBundleIdentifier

            // ~20 Hz counter updates. A 1000 Hz clicker would otherwise
            // trigger 1000 SwiftUI re-renders a second. Exact value on exit.
            var lastCounterPublish = ContinuousClock.now
            let counterInterval: Duration = .milliseconds(50)

            while !Task.isCancelled {
                if captured.stopAfterClicksEnabled, fired >= captured.stopAfterClicks { break }
                if captured.stopAfterDurationEnabled,
                   ContinuousClock.now - started >= .milliseconds(captured.stopAfterDurationMilliseconds) {
                    break
                }
                if captured.stopOnWindowChangeEnabled {
                    let current = self.watcher.frontmostBundleIdentifier
                    if let baseline = windowBaseline {
                        if current != baseline { break }
                    } else if let current, current != ownBundleID {
                        windowBaseline = current
                    }
                }

                let clickPoint = captured.positionMode == .fixed ? captured.fixedPosition : nil
                self.executor.injectClick(at: clickPoint, button: captured.button)
                fired += 1

                let now = ContinuousClock.now
                if now - lastCounterPublish >= counterInterval {
                    self.clicksFired = fired
                    lastCounterPublish = now
                }

                try? await Task.sleep(for: .milliseconds(Self.nextIntervalMs(for: captured)))
            }

            self.clicksFired = fired
            // Do not clobber a newer run.
            guard generation == self.runGeneration else { return }
            self.isRunning = false
            self.loopTask = nil
            Self.log.info("Autoclicker finished after \(fired, privacy: .public) clicks")
        }
    }

    func stop() {
        guard isRunning else { return }
        runGeneration += 1
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
        Self.log.info("Autoclicker stopped")
    }

    /// Never 0. A zero sleep busy-spins the main actor and Stop stops working.
    nonisolated static func nextIntervalMs(for config: AutoClickerConfig) -> Int {
        switch config.intervalMode {
        case .fixed:
            return max(1, config.intervalMilliseconds)
        case .random:
            let lo = max(1, min(config.intervalMinMilliseconds, config.intervalMaxMilliseconds))
            let hi = max(lo, config.intervalMaxMilliseconds)
            return Int.random(in: lo...hi)
        }
    }

    // MARK: - Hotkey wiring

    private func syncHotkeyRegistration() {
        if let token = hotkeyToken {
            hotkeys.unregister(token)
            hotkeyToken = nil
        }
        guard let hotkey = config.hotkey else { return }

        switch config.triggerMode {
        case .toggle:
            hotkeyToken = hotkeys.register(hotkey) { [weak self] in self?.toggle() }
        case .hold:
            hotkeyToken = hotkeys.registerHold(
                hotkey,
                onPress:   { [weak self] in self?.start() },
                onRelease: { [weak self] in self?.stop() }
            )
        }
    }

    // MARK: - Persistence

    private static func loadConfig() -> AutoClickerConfig {
        guard let data = UserDefaults.standard.data(forKey: configDefaultsKey) else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(AutoClickerConfig.self, from: data)
        } catch {
            log.error("Stored config unreadable, falling back to defaults: \(error.localizedDescription, privacy: .public)")
            return .defaults
        }
    }

    private func persistConfig() {
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: Self.configDefaultsKey)
        } catch {
            Self.log.error("Failed to persist config: \(error.localizedDescription, privacy: .public)")
        }
    }
}
