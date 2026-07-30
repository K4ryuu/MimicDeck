// Dropdown over running apps, bound to a WindowFilter. "Run anywhere" clears it.

import AppKit
import SwiftUI

struct WindowPickerField: View {
    @Environment(WindowWatcher.self) private var watcher
    @Binding var filter: WindowFilter?

    var body: some View {
        Menu {
            Button {
                filter = nil
            } label: {
                Label("Run anywhere", systemImage: "globe")
            }
            Divider()
            ForEach(watcher.runningApps()) { app in
                Button {
                    filter = WindowFilter(
                        bundleIdentifier: app.bundleIdentifier,
                        displayName: app.displayName
                    )
                } label: {
                    Label(app.displayName, systemImage: "app")
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let filter {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.tint)
                    Text(filter.displayName)
                } else {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                    Text("Anywhere")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 160)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
