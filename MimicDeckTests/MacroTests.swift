// Macro defaults, duplication, codable round-trip.

import Foundation
import Testing
@testable import MimicDeck

@Suite("Macro")
struct MacroTests {
    @Test("Default init populates timestamps and empty steps")
    func defaultsPopulate() {
        let macro = Macro(name: "Test")
        #expect(macro.name == "Test")
        #expect(macro.steps.isEmpty)
        #expect(macro.loopCount == 1)
        #expect(macro.windowFilter == nil)
        #expect(macro.hotkey == nil)
    }

    @Test("Duplication assigns a new ID and renames")
    func duplicate() {
        let original = Macro(name: "Farm")
        let copy = original.duplicated()
        #expect(copy.id != original.id)
        #expect(copy.name == "Farm (copy)")
    }

    @Test("Round-trips through JSON encoder")
    func codableRoundTrip() throws {
        let macro = Macro(
            name: "RT",
            steps: [.click(.left), .wait(milliseconds: 200), .key(0x31)],
            windowFilter: WindowFilter(bundleIdentifier: "com.example", displayName: "Example"),
            hotkey: Hotkey(keyCode: 0x12, modifiers: [.command]),
            loopCount: 3
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(macro)
        let restored = try decoder.decode(Macro.self, from: data)

        #expect(restored.id == macro.id)
        #expect(restored.steps.count == 3)
        #expect(restored.windowFilter?.bundleIdentifier == "com.example")
        #expect(restored.hotkey?.modifiers == [.command])
        #expect(restored.loopCount == 3)
    }
}
