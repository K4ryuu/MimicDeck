// Optional panic key that stops any registered runner. Off by default, so
// the global monitor is never installed unless the user opts in.
//
// Installing it at app init froze SwiftUI's event loop, hence the lazy
// install tied to the toggle.

import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class EmergencyStopService {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Emergency")
    private static let hotkeyDefaultsKey = "EmergencyStop.hotkey"
    private static let enabledDefaultsKey = "EmergencyStop.enabled"

    typealias Handler = @MainActor () -> Void

    private struct Runner {
        let id: UUID
        let isActive: @MainActor () -> Bool
        let stop: Handler
    }

    private(set) var triggerKey: Hotkey?

    /// Installs and tears down the global monitor.
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
            isEnabled ? installMonitor() : removeMonitor()
        }
    }

    private var runners: [UUID: Runner] = [:]
    private var globalMonitor: Any?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.hotkeyDefaultsKey),
           let stored = try? JSONDecoder().decode(Hotkey.self, from: data) {
            self.triggerKey = stored
        } else {
            self.triggerKey = Hotkey(keyCode: 0x35, modifiers: [])
        }
        // Off by default, the user opts in from Settings.
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        if self.isEnabled {
            // Let launch finish first, otherwise the app feels stuck.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.installMonitor()
            }
        }
    }

    func setTriggerKey(_ hotkey: Hotkey?) {
        triggerKey = hotkey
        if let hotkey, let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: Self.hotkeyDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.hotkeyDefaultsKey)
        }
    }

    @discardableResult
    func register(
        isActive: @escaping @MainActor () -> Bool,
        stop: @escaping Handler
    ) -> UUID {
        let id = UUID()
        runners[id] = Runner(id: id, isActive: isActive, stop: stop)
        return id
    }

    func unregister(_ token: UUID) {
        runners.removeValue(forKey: token)
    }

    private func installMonitor() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
        Self.log.info("Installed emergency-stop monitor")
    }

    private func removeMonitor() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
            Self.log.info("Removed emergency-stop monitor")
        }
    }

    private func handle(_ event: NSEvent) {
        guard isEnabled, let key = triggerKey else { return }
        guard UInt16(event.keyCode) == key.keyCode else { return }
        let mods = Hotkey.Modifiers(nsFlags: event.modifierFlags)
        if key.modifiers.isEmpty {
            guard mods.isEmpty else { return }
        } else {
            guard mods.contains(key.modifiers) else { return }
        }

        let active = runners.values.filter { $0.isActive() }
        guard !active.isEmpty else { return }
        Self.log.info("Emergency stop triggered: \(active.count, privacy: .public) runner(s)")
        for runner in active { runner.stop() }
    }
}
