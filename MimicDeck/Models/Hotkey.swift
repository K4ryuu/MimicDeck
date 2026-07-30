// A global hotkey: Carbon virtual key code plus modifier flags. Codable so
// it can sit inside Macro and AutoClickerConfig.
//
// Not NSEvent.modifierFlags, those serialise their whole bit layout.

import Foundation

nonisolated struct Hotkey: Codable, Hashable, Sendable {
    struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        let rawValue: UInt32

        static let command = Modifiers(rawValue: 1 << 0)
        static let option  = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let shift   = Modifiers(rawValue: 1 << 3)
    }

    var keyCode: UInt16
    var modifiers: Modifiers

    /// Renders like the user expects, e.g. "⌃⌥1". Modifier order per HIG.
    func displayString(keyName: String) -> String {
        var out = ""
        if modifiers.contains(.control) { out += "⌃" }
        if modifiers.contains(.option)  { out += "⌥" }
        if modifiers.contains(.shift)   { out += "⇧" }
        if modifiers.contains(.command) { out += "⌘" }
        out += keyName
        return out
    }
}
