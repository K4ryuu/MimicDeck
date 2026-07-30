// Modifier conversion and display tests for Hotkey.

import Foundation
import Testing
@testable import MimicDeck

@Suite("Hotkey")
struct HotkeyTests {
    @Test("Codable round-trip preserves keyCode + modifiers")
    func codableRoundTrip() throws {
        let original = Hotkey(keyCode: 0x12, modifiers: [.command, .shift])
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(Hotkey.self, from: data)
        #expect(restored == original)
    }

    @Test("Display string prefixes modifiers in HIG order")
    func display() {
        let hotkey = Hotkey(keyCode: 0x12, modifiers: [.command, .option, .control, .shift])
        let display = hotkey.displayString(keyName: "1")
        #expect(display == "⌃⌥⇧⌘1")
    }

    @Test("Empty modifier set has no prefix")
    func emptyDisplay() {
        let hotkey = Hotkey(keyCode: 0x31, modifiers: [])
        #expect(hotkey.displayString(keyName: "Space") == "Space")
    }
}
