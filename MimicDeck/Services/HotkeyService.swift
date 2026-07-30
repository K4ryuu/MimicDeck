// Global hotkeys, two flavours:
//   register(_:handler:)   Carbon RegisterEventHotKey, fires on press. Toggle.
//   registerHold(_:_:_:)   NSEvent monitors, separate down/up. Hold mode.
//
// Shared id namespace, so unregister(_:) handles either.

import AppKit
import Carbon.HIToolbox
import Foundation
import Observation
import os

@MainActor
@Observable
final class HotkeyService {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Hotkey")
    private static let signature: OSType = 0x4143_4D52 // "ACMR"

    typealias Handler = @MainActor () -> Void

    private struct ToggleRegistration {
        let id: UInt32
        let hotkey: Hotkey
        let ref: EventHotKeyRef
        let handler: Handler
    }

    private struct HoldRegistration {
        let id: UInt32
        let hotkey: Hotkey
        let onPress: Handler
        let onRelease: Handler
        var isHeld: Bool
    }

    private var toggleRegs: [UInt32: ToggleRegistration] = [:]
    private var holdRegs: [UInt32: HoldRegistration] = [:]
    private var nextID: UInt32 = 1
    private var carbonHandler: EventHandlerRef?
    private var holdGlobalMonitor: Any?
    private var holdLocalMonitor: Any?

    init() {
        installCarbonHandler()
    }

    // Lives for the app lifetime, so no deinit cleanup. Process exit
    // reclaims everything.

    // MARK: - Toggle registration (Carbon, fires on press)

    @discardableResult
    func register(_ hotkey: Hotkey, handler: @escaping Handler) -> UInt32? {
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            hotkey.modifiers.carbonFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            Self.log.error("RegisterEventHotKey failed: \(status, privacy: .public)")
            return nil
        }

        toggleRegs[id] = ToggleRegistration(id: id, hotkey: hotkey, ref: ref, handler: handler)
        Self.log.info("Registered toggle hotkey id=\(id, privacy: .public)")
        return id
    }

    // MARK: - Hold registration (NSEvent, separate down/up callbacks)

    @discardableResult
    func registerHold(_ hotkey: Hotkey,
                      onPress: @escaping Handler,
                      onRelease: @escaping Handler) -> UInt32 {
        let id = nextID
        nextID += 1
        holdRegs[id] = HoldRegistration(id: id, hotkey: hotkey,
                                        onPress: onPress, onRelease: onRelease,
                                        isHeld: false)
        installHoldMonitorsIfNeeded()
        Self.log.info("Registered hold hotkey id=\(id, privacy: .public)")
        return id
    }

    // MARK: - Unregister (works for either kind)

    func unregister(_ token: UInt32) {
        if let reg = toggleRegs.removeValue(forKey: token) {
            UnregisterEventHotKey(reg.ref)
            Self.log.info("Unregistered toggle hotkey id=\(token, privacy: .public)")
            return
        }
        if var reg = holdRegs.removeValue(forKey: token) {
            if reg.isHeld {
                reg.isHeld = false
                reg.onRelease()
            }
            teardownHoldMonitorsIfEmpty()
            Self.log.info("Unregistered hold hotkey id=\(token, privacy: .public)")
        }
    }

    // MARK: - Carbon plumbing (toggle)

    private func installCarbonHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return status }
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                let id = hkID.id
                Task { @MainActor in
                    service.fireToggle(id: id)
                }
                return noErr
            },
            1,
            &spec,
            context,
            &carbonHandler
        )
    }

    private func fireToggle(id: UInt32) {
        guard let reg = toggleRegs[id] else { return }
        Self.log.debug("Toggle hotkey \(id, privacy: .public) fired")
        reg.handler()
    }

    // MARK: - NSEvent monitor (hold)

    private func installHoldMonitorsIfNeeded() {
        guard holdGlobalMonitor == nil else { return }
        holdGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleHoldEvent(event)
            }
        }
        holdLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleHoldEvent(event)
            return event
        }
        Self.log.debug("Installed hold event monitors")
    }

    private func teardownHoldMonitorsIfEmpty() {
        guard holdRegs.isEmpty else { return }
        if let global = holdGlobalMonitor {
            NSEvent.removeMonitor(global)
            holdGlobalMonitor = nil
        }
        if let local = holdLocalMonitor {
            NSEvent.removeMonitor(local)
            holdLocalMonitor = nil
        }
        Self.log.debug("Removed hold event monitors")
    }

    private func handleHoldEvent(_ event: NSEvent) {
        let keyCode = UInt16(event.keyCode)
        for (id, var reg) in holdRegs {
            switch event.type {
            case .keyDown:
                if event.isARepeat { continue }
                let mods = Hotkey.Modifiers(nsFlags: event.modifierFlags)
                if !reg.isHeld
                    && keyCode == reg.hotkey.keyCode
                    && mods.contains(reg.hotkey.modifiers) {
                    reg.isHeld = true
                    holdRegs[id] = reg
                    reg.onPress()
                }
            case .keyUp:
                // No modifier match on key-up, people release those first.
                if reg.isHeld && keyCode == reg.hotkey.keyCode {
                    reg.isHeld = false
                    holdRegs[id] = reg
                    reg.onRelease()
                }
            default:
                break
            }
        }
    }
}

extension Hotkey.Modifiers {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option)  { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift)   { flags |= UInt32(shiftKey) }
        return flags
    }

    init(nsFlags: NSEvent.ModifierFlags) {
        var mods = Hotkey.Modifiers()
        if nsFlags.contains(.command)  { mods.insert(.command) }
        if nsFlags.contains(.option)   { mods.insert(.option) }
        if nsFlags.contains(.control)  { mods.insert(.control) }
        if nsFlags.contains(.shift)    { mods.insert(.shift) }
        self = mods
    }
}
