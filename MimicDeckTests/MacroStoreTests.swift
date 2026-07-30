// CRUD and on-disk round-trip, against a temp file rather than the user's
// real Application Support.

import Foundation
import Testing
@testable import MimicDeck

@Suite("MacroStore")
@MainActor
struct MacroStoreTests {
    private func tempFile() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MimicDeckTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("macros.json")
    }

    @Test("Empty store starts with no macros")
    func emptyStart() {
        let store = MacroStore(fileURL: tempFile())
        #expect(store.macros.isEmpty)
    }

    @Test("Add → flush → reload preserves macros")
    func persistRoundTrip() {
        let file = tempFile()
        do {
            let store = MacroStore(fileURL: file)
            store.add(Macro(name: "A"))
            store.add(Macro(name: "B", steps: [.click(.left), .wait(milliseconds: 50)]))
            store.flush()
        }

        let reopened = MacroStore(fileURL: file)
        #expect(reopened.macros.count == 2)
        #expect(reopened.macros.map(\.name) == ["A", "B"])
        #expect(reopened.macros[1].steps.count == 2)
    }

    @Test("Update changes the existing macro and bumps timestamp")
    func update() {
        let store = MacroStore(fileURL: tempFile())
        var macro = Macro(name: "Original")
        store.add(macro)
        let beforeUpdate = store.macros[0].updatedAt
        // nudge the clock so the timestamp actually moves on fast CI
        Thread.sleep(forTimeInterval: 0.01)
        macro.name = "Updated"
        store.update(macro)
        #expect(store.macros[0].name == "Updated")
        #expect(store.macros[0].updatedAt > beforeUpdate)
    }

    @Test("Remove deletes by ID")
    func remove() {
        let store = MacroStore(fileURL: tempFile())
        let a = Macro(name: "A")
        let b = Macro(name: "B")
        store.add(a)
        store.add(b)
        store.remove(id: a.id)
        #expect(store.macros.count == 1)
        #expect(store.macros[0].id == b.id)
    }

    @Test("Duplicate returns a fresh copy with new ID")
    func duplicate() {
        let store = MacroStore(fileURL: tempFile())
        let a = Macro(name: "A")
        store.add(a)
        let copy = store.duplicate(id: a.id)
        #expect(copy != nil)
        #expect(copy?.id != a.id)
        #expect(store.macros.count == 2)
    }

    @Test("Export then import round-trips with fresh IDs")
    func exportImportRoundTrip() throws {
        let store = MacroStore(fileURL: tempFile())
        let original = Macro(name: "Shared", steps: [.click(.left), .type("hi")])
        store.add(original)

        let data = try store.exportData(for: [original.id])
        let imported = try store.importData(data)

        #expect(imported.count == 1)
        #expect(imported[0].name == "Shared")
        #expect(imported[0].id != original.id)
        #expect(imported[0].steps.count == 2)
        // Step ids have to be fresh too, otherwise ForEach sees duplicates.
        #expect(imported[0].steps[0].id != original.steps[0].id)
    }

    @Test("A bundle from a newer format version is refused")
    func rejectsNewerBundleVersion() throws {
        let bundle = MacroStore.Bundle(
            version: MacroStore.currentBundleVersion + 1,
            macros: [Macro(name: "From the future")]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)

        #expect(throws: MacroStore.ImportError.self) {
            try MacroStore.decodeBundle(data)
        }
    }

    @Test("An absurdly large file is refused before it reaches the decoder")
    func rejectsOversizedBundle() {
        let data = Data(repeating: 0x7B, count: MacroStore.maxImportBytes + 1)
        #expect(throws: MacroStore.ImportError.self) {
            try MacroStore.decodeBundle(data)
        }
    }

    @Test("Garbage input throws instead of crashing")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            try MacroStore.decodeBundle(Data("not json at all".utf8))
        }
    }
}
