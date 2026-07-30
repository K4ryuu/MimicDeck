// One step in a macro: click, key combo, wait, typed text or cursor move.
//
// Looping is Macro.loopCount, not a nested loop step. Keeps the editor flat
// and the state machine small.

import CoreGraphics
import Foundation

nonisolated enum MacroStep: Codable, Identifiable, Hashable, Sendable {
    enum ClickPosition: Codable, Hashable, Sendable {
        case currentCursor
        case fixed(x: CGFloat, y: CGFloat)

        var point: CGPoint? {
            switch self {
            case .currentCursor:        nil
            case .fixed(let x, let y):  CGPoint(x: x, y: y)
            }
        }
    }

    /// Editor display hint only. Values are always stored in ms.
    enum DurationUnit: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
        case ms, s, m, h

        var id: String { rawValue }

        var title: String {
            switch self {
            case .ms: "ms"
            case .s:  "s"
            case .m:  "min"
            case .h:  "h"
            }
        }

        var msPerUnit: Int {
            switch self {
            case .ms: 1
            case .s:  1_000
            case .m:  60_000
            case .h:  3_600_000
            }
        }
    }

    enum WaitDuration: Codable, Hashable, Sendable {
        case fixed(milliseconds: Int, unit: DurationUnit)
        case random(minMs: Int, maxMs: Int, unit: DurationUnit)

        var sampledMilliseconds: Int {
            switch self {
            case .fixed(let ms, _):
                return max(0, ms)
            case .random(let lo, let hi, _):
                let a = max(0, min(lo, hi))
                let b = max(0, max(lo, hi))
                return Int.random(in: a...b)
            }
        }

        var unit: DurationUnit {
            switch self {
            case .fixed(_, let u):     u
            case .random(_, _, let u): u
            }
        }

        var summary: String {
            switch self {
            case .fixed(let ms, let unit):
                return formatted(ms: ms, unit: unit)
            case .random(let lo, let hi, let unit):
                return "\(formatted(ms: lo, unit: unit)) to \(formatted(ms: hi, unit: unit)) random"
            }
        }

        private func formatted(ms: Int, unit: DurationUnit) -> String {
            if unit == .ms { return "\(ms) ms" }
            let value = Double(ms) / Double(unit.msPerUnit)
            let fmt = value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f"
            return "\(String(format: fmt, value)) \(unit.title)"
        }
    }

    case click(id: UUID, button: MouseButton, position: ClickPosition)
    case key(id: UUID, keyCode: UInt16, modifiers: Hotkey.Modifiers)
    case wait(id: UUID, duration: WaitDuration)
    case type(id: UUID, text: String)
    case move(id: UUID, toX: CGFloat, toY: CGFloat, durationMs: Int)

    var id: UUID {
        switch self {
        case .click(let id, _, _):       id
        case .key(let id, _, _):         id
        case .wait(let id, _):           id
        case .type(let id, _):           id
        case .move(let id, _, _, _):     id
        }
    }

    // MARK: Factories (IDs auto-generated)

    static func click(_ button: MouseButton, at position: ClickPosition = .currentCursor) -> MacroStep {
        .click(id: UUID(), button: button, position: position)
    }

    static func key(_ keyCode: UInt16, modifiers: Hotkey.Modifiers = []) -> MacroStep {
        .key(id: UUID(), keyCode: keyCode, modifiers: modifiers)
    }

    static func wait(milliseconds ms: Int, unit: DurationUnit = .ms) -> MacroStep {
        .wait(id: UUID(), duration: .fixed(milliseconds: max(0, ms), unit: unit))
    }

    static func waitRandom(minMs: Int, maxMs: Int, unit: DurationUnit = .ms) -> MacroStep {
        .wait(id: UUID(), duration: .random(minMs: max(0, minMs), maxMs: max(0, maxMs), unit: unit))
    }

    static func type(_ text: String) -> MacroStep {
        .type(id: UUID(), text: text)
    }

    static func move(toX: CGFloat, toY: CGFloat, durationMs: Int = 100) -> MacroStep {
        .move(id: UUID(), toX: toX, toY: toY, durationMs: max(0, durationMs))
    }

    /// Same step, fresh id. Used by the duplicate button and by import, so a
    /// re-imported file never collides with what is already stored.
    func duplicated() -> MacroStep {
        switch self {
        case .click(_, let button, let position):  .click(id: UUID(), button: button, position: position)
        case .key(_, let keyCode, let modifiers):  .key(id: UUID(), keyCode: keyCode, modifiers: modifiers)
        case .wait(_, let duration):               .wait(id: UUID(), duration: duration)
        case .type(_, let text):                   .type(id: UUID(), text: text)
        case .move(_, let x, let y, let ms):       .move(id: UUID(), toX: x, toY: y, durationMs: ms)
        }
    }

    // MARK: Display

    var summary: String {
        switch self {
        case .click(_, let button, .currentCursor):
            "\(button.displayName) at cursor"
        case .click(_, let button, .fixed(let x, let y)):
            "\(button.displayName) at (\(Int(x)), \(Int(y)))"
        case .key(_, let keyCode, let mods):
            "Key \(mods.displayPrefix)\(KeyName.forVirtualKey(keyCode))"
        case .wait(_, let duration):
            "Wait \(duration.summary)"
        case .type(_, let text):
            "Type “\(text.prefix(40))\(text.count > 40 ? "…" : "")”"
        case .move(_, let x, let y, let ms):
            "Move to (\(Int(x)), \(Int(y))) in \(ms) ms"
        }
    }
}

extension Hotkey.Modifiers {
    nonisolated var displayPrefix: String {
        var out = ""
        if contains(.control) { out += "⌃" }
        if contains(.option)  { out += "⌥" }
        if contains(.shift)   { out += "⇧" }
        if contains(.command) { out += "⌘" }
        return out
    }
}
