// List of stored macros: empty state, per-row preview, context menu, filter,
// and import/export of macro bundles.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MacroListView: View {
    @Environment(MacroStore.self) private var store
    @Binding var selection: UUID?

    @State private var renamingID: UUID?
    @State private var renameDraft: String = ""
    @State private var confirmingDeleteID: UUID?
    @State private var searchText: String = ""

    private var filteredMacros: [Macro] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.macros }
        return store.macros.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if store.macros.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            confirmingDeleteName.map { "Delete \"\($0)\"?" } ?? "Delete macro?",
            isPresented: Binding(
                get: { confirmingDeleteID != nil },
                set: { if !$0 { confirmingDeleteID = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let id = confirmingDeleteID {
                    store.remove(id: id)
                    if selection == id { selection = nil }
                }
                confirmingDeleteID = nil
            }
            Button("Cancel", role: .cancel) {
                confirmingDeleteID = nil
            }
        } message: {
            Text("This permanently removes the macro and all of its steps.")
        }
    }

    private var confirmingDeleteName: String? {
        guard let id = confirmingDeleteID else { return nil }
        return store.macros.first(where: { $0.id == id })?.name
    }

    private var list: some View {
        List(selection: $selection) {
            Section(header: listHeader) {
                if filteredMacros.isEmpty {
                    Text("No macro matches \"\(searchText)\"")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(filteredMacros) { macro in
                        row(for: macro)
                            .tag(macro.id)
                            .contextMenu { contextMenu(for: macro) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Filter macros")
    }

    private var listHeader: some View {
        HStack(spacing: 8) {
            Text("Macros")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(store.macros.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.background.tertiary, in: Capsule())

            Spacer()

            Button(action: createNew) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Create a new macro")

            Menu {
                Button {
                    importMacros()
                } label: {
                    Label("Import…", systemImage: "tray.and.arrow.down")
                }
                Button {
                    exportAll()
                } label: {
                    Label("Export all…", systemImage: "tray.and.arrow.up")
                }
                .disabled(store.macros.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("Import or export macros")
            .padding(.trailing, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: 4) {
                Text("No macros yet")
                    .font(.headline)
                Text("Create your first macro to get started.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 8) {
                Button(action: createNew) {
                    Label("Create macro", systemImage: "plus")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                // The import entry lives in the list header, which only exists
                // once there is a list. Without this, a fresh install has no
                // way to bring in a shared macro.
                Button(action: importMacros) {
                    Label("Import…", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func row(for macro: Macro) -> some View {
        if renamingID == macro.id {
            TextField("Name", text: $renameDraft, onCommit: { commitRename(for: macro) })
                .textFieldStyle(.roundedBorder)
                .onExitCommand { renamingID = nil }
        } else {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: macro.steps.isEmpty ? "circle.dashed" : macro.symbol)
                    .foregroundStyle(macro.steps.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                    .imageScale(.medium)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(macro.name)
                        .font(.body)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(macro.steps.count) step\(macro.steps.count == 1 ? "" : "s")")
                        if let filter = macro.windowFilter {
                            Text("·").foregroundStyle(.tertiary)
                            Image(systemName: "app")
                                .imageScale(.small)
                            Text(filter.displayName).lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if macro.hotkey != nil {
                    Image(systemName: "command.square")
                        .foregroundStyle(.secondary)
                        .help("Has a hotkey assigned")
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func contextMenu(for macro: Macro) -> some View {
        Button("Rename") { startRename(macro) }
        Button("Duplicate") { _ = store.duplicate(id: macro.id) }
        Button("Export…") { exportSingle(macro) }
        Divider()
        Button("Delete…", role: .destructive) {
            confirmingDeleteID = macro.id
        }
    }

    // MARK: - Actions

    private func createNew() {
        let macro = Macro(name: "Untitled Macro")
        store.add(macro)
        selection = macro.id
        startRename(macro)
    }

    private func startRename(_ macro: Macro) {
        renamingID = macro.id
        renameDraft = macro.name
    }

    private func commitRename(for macro: Macro) {
        var updated = macro
        let trimmed = renameDraft.trimmingCharacters(in: .whitespaces)
        updated.name = trimmed.isEmpty ? macro.name : trimmed
        store.update(updated)
        renamingID = nil
    }

    // MARK: - Import / Export

    private func exportSingle(_ macro: Macro) {
        guard let data = try? store.exportData(for: [macro.id]) else { return }
        saveBundle(data: data, suggestedName: sanitized(macro.name))
    }

    private func exportAll() {
        guard let data = try? store.exportData() else { return }
        saveBundle(data: data, suggestedName: "MimicDeck macros")
    }

    private func importMacros() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .data]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import macros"
        panel.message = "Choose an MimicDeck macro file to import."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let bundle = try MacroStore.decodeBundle(try Data(contentsOf: url))
            guard confirmImport(of: bundle, from: url) else { return }
            if let first = store.importBundle(bundle).first {
                selection = first.id
            }
        } catch {
            presentError("Couldn't import macros", message: error.localizedDescription)
        }
    }

    /// A macro file is somebody else's input sequence. Say what is in it
    /// before it lands in the library, and be blunt when it types.
    private func confirmImport(of bundle: MacroStore.Bundle, from url: URL) -> Bool {
        let steps = bundle.macros.reduce(0) { $0 + $1.steps.count }
        let sendsKeystrokes = bundle.macros.contains { macro in
            macro.steps.contains {
                switch $0 {
                case .key, .type: true
                default:          false
                }
            }
        }

        let alert = NSAlert()
        alert.messageText = bundle.macros.count == 1
            ? "Import \"\(bundle.macros[0].name)\"?"
            : "Import \(bundle.macros.count) macros?"
        alert.informativeText = """
            \(url.lastPathComponent) contains \(steps) step\(steps == 1 ? "" : "s").

            \(sendsKeystrokes
                ? "It presses keys and types text into whatever app is focused when you run it. Only import files you trust, and read the steps before running them."
                : "It sends mouse clicks to whatever is on screen when you run it. Only import files you trust.")
            """
        alert.alertStyle = sendsKeystrokes ? .warning : .informational
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func saveBundle(data: Data, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(suggestedName).\(MacroStore.exportFileExtension)"
        panel.title = "Export macros"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            presentError("Couldn't save the file", message: error.localizedDescription)
        }
    }

    private func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Macro" : trimmed
    }

    private func presentError(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
