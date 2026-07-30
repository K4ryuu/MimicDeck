// CGEvent posting for input injection: clicks, keys, unicode text.
// Recording lives in MacroRecorder with its own listen-only tap. Both need
// Accessibility.

import AppKit
import CoreGraphics
import Foundation
import Observation
import os

@MainActor
@Observable
final class EventTapService: StepExecutor {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "EventTap")

    // MARK: - Click injection

    /// `point` is CGEvent space (top-left origin). nil means current cursor.
    func injectClick(at point: CGPoint? = nil, button: MouseButton = .left) {
        let position = point ?? Self.currentCursorPosition()
        guard
            let down = CGEvent(mouseEventSource: nil, mouseType: button.downType,
                               mouseCursorPosition: position, mouseButton: button.cgButton),
            let up = CGEvent(mouseEventSource: nil, mouseType: button.upType,
                             mouseCursorPosition: position, mouseButton: button.cgButton)
        else {
            Self.log.error("Failed to create CGEvent for click")
            return
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        // .debug on purpose, a 1 kHz clicker would flood the log with one
        // interpolation per click.
        Self.log.debug("Injected \(String(describing: button), privacy: .public) click")
    }

    // MARK: - Keyboard injection

    func injectKey(_ keyCode: UInt16, modifiers: Hotkey.Modifiers = []) {
        guard
            let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true),
            let up   = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false)
        else {
            Self.log.error("Failed to create CGEvent for key \(keyCode, privacy: .public)")
            return
        }
        let cgFlags = modifiers.cgEventFlags
        down.flags = cgFlags
        up.flags = cgFlags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        Self.log.debug("Injected key \(keyCode, privacy: .public) mods=\(modifiers.rawValue, privacy: .public)")
    }

    /// Uses keyboardSetUnicodeString, so it ignores the active layout.
    func typeText(_ text: String) {
        for scalar in text.unicodeScalars {
            let utf16Units = Array(String(scalar).utf16)
            guard
                let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            else { continue }

            utf16Units.withUnsafeBufferPointer { buf in
                if let base = buf.baseAddress {
                    down.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: base)
                    up.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: base)
                }
            }
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
        Self.log.debug("Typed string of length \(text.count, privacy: .public)")
    }

    // MARK: - StepExecutor

    /// Interpolates at ~120 Hz. Warps instantly when durationMs is 0.
    func moveCursor(to target: CGPoint, durationMs: Int) async {
        let start = Self.currentCursorPosition()
        guard durationMs > 0 else {
            postMove(to: target)
            return
        }
        let stepCount = max(1, durationMs / 8)
        let perStepMs = max(1, durationMs / stepCount)
        for i in 1...stepCount {
            let t = CGFloat(i) / CGFloat(stepCount)
            let interp = CGPoint(
                x: start.x + (target.x - start.x) * t,
                y: start.y + (target.y - start.y) * t
            )
            postMove(to: interp)
            try? await Task.sleep(for: .milliseconds(perStepMs))
        }
    }

    private func postMove(to point: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    func execute(_ step: MacroStep) async {
        switch step {
        case .click(_, let button, let position):
            injectClick(at: position.point, button: button)
        case .key(_, let keyCode, let mods):
            injectKey(keyCode, modifiers: mods)
        case .wait(_, let duration):
            try? await Task.sleep(for: .milliseconds(duration.sampledMilliseconds))
        case .type(_, let text):
            typeText(text)
        case .move(_, let x, let y, let ms):
            await moveCursor(to: CGPoint(x: x, y: y), durationMs: ms)
        }
    }

    // MARK: - Helpers

    /// Cursor in CGEvent space.
    static func currentCursorPosition() -> CGPoint {
        ScreenGeometry.currentCursor()
    }
}

extension Hotkey.Modifiers {
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.option)  { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.shift)   { flags.insert(.maskShift) }
        return flags
    }
}
