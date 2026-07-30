// Turns real clicks and key presses into MacroSteps via a listen-only
// CGEventTap, with wait steps preserving the original timing.
//
// Mouse movement is deliberately not captured: it produced hundreds of steps
// a second and made the editor unusable. Add .move steps by hand instead.
//
// Needs Accessibility, plus Input Monitoring (separate TCC bucket) for keys.

import AppKit
import CoreGraphics
import Foundation
import Observation
import os

@MainActor
@Observable
final class MacroRecorder {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Recorder")

    /// Biggest gap between two .type steps that still merges into one
    /// string. 500 ms covers ~40 wpm plus a short think. Longer is deliberate.
    nonisolated static let typeMergeWaitThresholdMs = 500

    private(set) var isRecording = false
    /// Set when the tap could not be created, which in practice means macOS
    /// refused the permission. Reported rather than guessed at up front: the
    /// preflight checks claim Input Monitoring is missing even on machines
    /// where recording works fine through Accessibility.
    private(set) var startFailure: String?
    private(set) var captured: [MacroStep] = []

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastEventDate: Date?

    // MARK: - Recording lifecycle

    func start() {
        guard !isRecording else { return }
        captured.removeAll()
        lastEventDate = nil

        let mask: CGEventMask =
              (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.keyDown.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let recorder = Unmanaged<MacroRecorder>.fromOpaque(refcon).takeUnretainedValue()
                Task { @MainActor in
                    recorder.handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: context
        ) else {
            startFailure = "macOS refused the event tap. Check that MimicDeck is switched on under Privacy & Security, Accessibility."
            Self.log.error("Failed to create recording tap, missing permission?")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        self.isRecording = true
        self.startFailure = nil
        Self.log.info("Recording started")
    }

    @discardableResult
    func stop() -> [MacroStep] {
        guard isRecording else { return [] }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isRecording = false
        let merged = Self.mergeAdjacentTypedText(captured)
        captured = merged
        Self.log.info("Recording stopped: \(merged.count, privacy: .public) steps after merge")
        return captured
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) {
        appendWaitSinceLastEvent()

        switch type {
        case .leftMouseDown:
            captured.append(.click(.left, at: positionStep(for: event)))
        case .rightMouseDown:
            captured.append(.click(.right, at: positionStep(for: event)))
        case .otherMouseDown:
            captured.append(.click(.middle, at: positionStep(for: event)))
        case .keyDown:
            captured.append(stepForKeyDown(event))
        default:
            break
        }
    }

    /// Plain text (a, Q, space) or a key combo (⌘C, Return, Esc)?
    private func stepForKeyDown(_ event: CGEvent) -> MacroStep {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let mods = Hotkey.Modifiers(cgFlags: event.flags)

        // Plain typing only when no command/control/option. Shift just
        // changes case.
        let isModified = mods.contains(.command)
            || mods.contains(.control)
            || mods.contains(.option)
        if !isModified, let typed = typedCharacter(from: event), isPrintable(typed) {
            return .type(typed)
        }
        return .key(keyCode, modifiers: mods)
    }

    private func typedCharacter(from event: CGEvent) -> String? {
        var actualLength = 0
        var buffer: [UniChar] = Array(repeating: 0, count: 4)
        buffer.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            event.keyboardGetUnicodeString(
                maxStringLength: buf.count,
                actualStringLength: &actualLength,
                unicodeString: base
            )
        }
        guard actualLength > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: actualLength)
    }

    private func isPrintable(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        return string.unicodeScalars.allSatisfy { scalar in
            // Reject ASCII control characters and DEL.
            scalar.value >= 0x20 && scalar.value != 0x7F
        }
    }

    private func positionStep(for event: CGEvent) -> MacroStep.ClickPosition {
        let loc = event.location
        return .fixed(x: loc.x, y: loc.y)
    }

    private func appendWaitSinceLastEvent() {
        let now = Date()
        defer { lastEventDate = now }
        guard let last = lastEventDate else { return }
        let ms = Int(now.timeIntervalSince(last) * 1000.0)
        guard ms > 0 else { return }
        captured.append(.wait(milliseconds: ms))
    }

    // MARK: - Post-processing

    /// Merges runs of .type steps, hopping over the short waits that came
    /// from typing rhythm, into one .type. Longer waits stay as real pauses.
    nonisolated static func mergeAdjacentTypedText(_ steps: [MacroStep]) -> [MacroStep] {
        var result: [MacroStep] = []
        var index = 0

        while index < steps.count {
            guard case .type(_, let initialText) = steps[index] else {
                result.append(steps[index])
                index += 1
                continue
            }

            var combined = initialText
            var cursor = index + 1
            while cursor < steps.count {
                if case .type(_, let nextText) = steps[cursor] {
                    combined += nextText
                    cursor += 1
                    continue
                }
                if case .wait(_, .fixed(let ms, _)) = steps[cursor],
                   ms < typeMergeWaitThresholdMs,
                   cursor + 1 < steps.count,
                   case .type = steps[cursor + 1] {
                    cursor += 1
                    continue
                }
                break
            }

            result.append(.type(combined))
            index = cursor
        }

        return result
    }
}

extension Hotkey.Modifiers {
    init(cgFlags: CGEventFlags) {
        var mods = Hotkey.Modifiers()
        if cgFlags.contains(.maskCommand)   { mods.insert(.command) }
        if cgFlags.contains(.maskAlternate) { mods.insert(.option) }
        if cgFlags.contains(.maskControl)   { mods.insert(.control) }
        if cgFlags.contains(.maskShift)     { mods.insert(.shift) }
        self = mods
    }
}
