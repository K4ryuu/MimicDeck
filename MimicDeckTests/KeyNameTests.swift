// Lookup table and hex fallback for KeyName.

import Testing
@testable import MimicDeck

@Suite("KeyName")
struct KeyNameTests {
    @Test("Known virtual keys resolve to readable names")
    func knownKeys() {
        #expect(KeyName.forVirtualKey(0x00) == "A")
        #expect(KeyName.forVirtualKey(0x31) == "Space")
        #expect(KeyName.forVirtualKey(0x24) == "Return")
        #expect(KeyName.forVirtualKey(0x35) == "Esc")
    }

    @Test("Unknown keys fall back to hex")
    func unknownFallback() {
        #expect(KeyName.forVirtualKey(0xFE) == "0xFE")
    }
}
