// Dock icon on = .regular activation policy. Off = .accessory plus a menu
// bar status item that toggles the window.
//
// SettingsView owns the preference, this flips the actual runtime state.

import AppKit
import SwiftUI

@MainActor
final class DockController: NSObject {
    static let preferenceKey = "showInDock"

    /// One per app, so the status item and the activation policy stay in sync.
    static let shared = DockController()

    private var statusItem: NSStatusItem?

    /// Defaults to true on first launch.
    static var defaultShowInDock: Bool {
        if UserDefaults.standard.object(forKey: preferenceKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: preferenceKey)
    }

    /// Safe to call any time, idempotent.
    func apply(showInDock: Bool) {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
            removeStatusItem()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.canBecomeMain })?
                .makeKeyAndOrderFront(nil)
        } else {
            NSApp.setActivationPolicy(.accessory)
            installStatusItem()
        }
    }

    // MARK: - Status item plumbing

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "cursorarrow.click.2",
            accessibilityDescription: "MimicDeck"
        )
        item.button?.target = self
        item.button?.action = #selector(handleStatusItemClick)
        statusItem = item
    }

    private func removeStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    @objc private func handleStatusItemClick() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
