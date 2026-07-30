// Macro list as JSON in Application Support:
// ~/Library/Application Support/KitsuneLab/MimicDeck/macros.json
//
// Loads synchronously at init (small file). Writes are debounced so editing
// a step does not hit the disk on every keystroke.

import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class MacroStore {
    private static let log = Logger(subsystem: "KitsuneLab.MimicDeck", category: "Store")

    private(set) var macros: [Macro] = []
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let dir = base.appendingPathComponent("KitsuneLab/MimicDeck", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("macros.json")
        }
        load()
        observeTermination()
    }

    /// Writes are debounced 250 ms, so quitting right after an edit would
    /// drop it.
    private func observeTermination() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
    }

    // MARK: - Mutations

    func add(_ macro: Macro) {
        macros.append(macro)
        scheduleSave()
    }

    func update(_ macro: Macro) {
        guard let idx = macros.firstIndex(where: { $0.id == macro.id }) else {
            Self.log.error("update() called with unknown macro id \(macro.id, privacy: .public)")
            return
        }
        var updated = macro
        updated.updatedAt = .now
        macros[idx] = updated
        scheduleSave()
    }

    func remove(id: UUID) {
        macros.removeAll(where: { $0.id == id })
        scheduleSave()
    }

    func duplicate(id: UUID) -> Macro? {
        guard let original = macros.first(where: { $0.id == id }) else { return nil }
        let copy = original.duplicated()
        macros.append(copy)
        scheduleSave()
        return copy
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Self.log.info("No macros file yet at \(self.fileURL.path, privacy: .public)")
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            macros = try decoder.decode([Macro].self, from: data)
            Self.log.info("Loaded \(self.macros.count, privacy: .public) macros")
        } catch {
            Self.log.error("Failed to load macros: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(macros)
            try data.write(to: fileURL, options: .atomic)
            Self.log.debug("Saved \(self.macros.count, privacy: .public) macros")
        } catch {
            Self.log.error("Failed to save macros: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Synchronous save, skips the debounce.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        saveNow()
    }

    // MARK: - Import / Export

    /// Wire format for sharing macros between machines.
    nonisolated struct Bundle: Codable, Sendable {
        var version: Int
        var macros: [Macro]
    }

    nonisolated static let currentBundleVersion = 1
    nonisolated static let exportFileExtension = "mimicdeck"

    /// Encode `ids`, or everything when nil.
    func exportData(for ids: Set<UUID>? = nil) throws -> Data {
        let selected: [Macro]
        if let ids {
            selected = macros.filter { ids.contains($0.id) }
        } else {
            selected = macros
        }
        let bundle = Bundle(version: Self.currentBundleVersion, macros: selected)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    /// A bundle arrives from outside the app, so it gets checked before it
    /// gets decoded.
    nonisolated enum ImportError: LocalizedError {
        case tooLarge(bytes: Int)
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .tooLarge(let bytes):
                "That file is \(bytes / 1_000_000) MB. Macro bundles are a few kilobytes, so this probably isn't one."
            case .unsupportedVersion(let version):
                "This bundle uses format version \(version), which this build doesn't know. Update MimicDeck and try again."
            }
        }
    }

    /// A real bundle is kilobytes. The cap stops a huge or bogus file from
    /// locking up the UI in the decoder.
    nonisolated static let maxImportBytes = 10_000_000

    /// Decode without touching the store, so the UI can tell the user what is
    /// in a file before they commit to importing it.
    nonisolated static func decodeBundle(_ data: Data) throws -> Bundle {
        guard data.count <= maxImportBytes else {
            throw ImportError.tooLarge(bytes: data.count)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(Bundle.self, from: data)
        guard bundle.version <= currentBundleVersion else {
            throw ImportError.unsupportedVersion(bundle.version)
        }
        return bundle
    }

    /// Appends the bundle with fresh ids, so importing twice duplicates
    /// instead of overwriting. Returns what was added.
    @discardableResult
    func importBundle(_ bundle: Bundle) -> [Macro] {
        let fresh = bundle.macros.map(Self.regenerateIDs(in:))
        macros.append(contentsOf: fresh)
        scheduleSave()
        Self.log.info("Imported \(fresh.count, privacy: .public) macro(s)")
        return fresh
    }

    @discardableResult
    func importData(_ data: Data) throws -> [Macro] {
        importBundle(try Self.decodeBundle(data))
    }

    private static func regenerateIDs(in macro: Macro) -> Macro {
        var copy = macro
        copy.id = UUID()
        copy.steps = copy.steps.map { $0.duplicated() }
        copy.updatedAt = .now
        return copy
    }
}
