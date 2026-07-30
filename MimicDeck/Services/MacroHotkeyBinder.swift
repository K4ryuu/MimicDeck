// Keeps a global hotkey registered for every macro that has one, for the
// whole app lifetime.
//
// This used to live in MacroEditorView, so a hotkey only worked while its
// macro was open, and it fired against the Macro captured at registration
// time. Steps added later were ignored.

import Foundation
import Observation
import os

@MainActor
final class MacroHotkeyBinder {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "MacroHotkeys")

    private let store: MacroStore
    private let engine: MacroEngine
    private let hotkeys: HotkeyService

    /// macro id -> (the hotkey we registered, its service token).
    private var bindings: [UUID: (hotkey: Hotkey, token: UInt32)] = [:]

    init(store: MacroStore, engine: MacroEngine, hotkeys: HotkeyService) {
        self.store = store
        self.engine = engine
        self.hotkeys = hotkeys
        sync()
        observeStore()
    }

    /// Only touch what changed. The store publishes on every keystroke of a
    /// rename, and re-registering Carbon hotkeys that often drops presses.
    private func sync() {
        let desired: [UUID: Hotkey] = store.macros.reduce(into: [:]) { result, macro in
            if let hotkey = macro.hotkey { result[macro.id] = hotkey }
        }

        for (id, binding) in bindings where desired[id] != binding.hotkey {
            hotkeys.unregister(binding.token)
            bindings[id] = nil
        }

        for (id, hotkey) in desired where bindings[id] == nil {
            guard let token = hotkeys.register(hotkey, handler: { [weak self] in
                self?.fire(macroID: id)
            }) else {
                Self.log.error("Could not bind hotkey for macro \(id, privacy: .public)")
                continue
            }
            bindings[id] = (hotkey, token)
        }
    }

    /// Look it up now, not at registration time, so it runs current steps.
    private func fire(macroID: UUID) {
        if engine.isRunning {
            engine.stop()
            return
        }
        guard let macro = store.macros.first(where: { $0.id == macroID }) else { return }
        Task { await engine.run(macro) }
    }

    /// Observation fires once, so re-arm every time. Reading the values is
    /// what subscribes us.
    private func observeStore() {
        withObservationTracking {
            _ = store.macros.map { ($0.id, $0.hotkey) }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.sync()
                self.observeStore()
            }
        }
    }
}
