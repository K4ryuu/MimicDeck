// Click to capture, press a combo to set it, Esc clears, click away cancels.

import AppKit
import SwiftUI

struct HotkeyRecorderField: View {
    @Binding var hotkey: Hotkey?
    @State private var isCapturing: Bool = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleCapturing) {
            HStack(spacing: 6) {
                Image(systemName: isCapturing ? "record.circle" : "keyboard")
                    .foregroundStyle(isCapturing ? .red : .secondary)
                Text(displayText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if hotkey != nil && !isCapturing {
                    Button {
                        hotkey = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.background.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isCapturing ? Color.red : Color.secondary.opacity(0.2),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 160)
        .onDisappear { stopCapturing() }
    }

    private var displayText: String {
        if isCapturing { return "Press a key combo (Esc to clear)" }
        guard let hotkey else { return "Click to set" }
        return hotkey.displayString(keyName: KeyName.forVirtualKey(hotkey.keyCode))
    }

    private func toggleCapturing() {
        isCapturing ? stopCapturing() : startCapturing()
    }

    private func startCapturing() {
        guard !isCapturing else { return }
        isCapturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                handleKeyDown(event)
                return nil
            }
            return event
        }
    }

    private func stopCapturing() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isCapturing = false
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 0x35 {
            hotkey = nil
            stopCapturing()
            return
        }
        var mods = Hotkey.Modifiers()
        if event.modifierFlags.contains(.command)  { mods.insert(.command) }
        if event.modifierFlags.contains(.option)   { mods.insert(.option) }
        if event.modifierFlags.contains(.control)  { mods.insert(.control) }
        if event.modifierFlags.contains(.shift)    { mods.insert(.shift) }
        hotkey = Hotkey(keyCode: UInt16(event.keyCode), modifiers: mods)
        stopCapturing()
    }
}
