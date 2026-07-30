// App entry point. Builds the shared services once and drops them into the
// environment.

import SwiftUI

@main
struct MimicDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var permissions: PermissionManager
    @State private var eventTap: EventTapService
    @State private var watcher: WindowWatcher
    @State private var store: MacroStore
    @State private var engine: MacroEngine
    @State private var recorder: MacroRecorder
    @State private var hotkeys: HotkeyService
    @State private var emergency: EmergencyStopService
    @State private var updates = UpdateChecker()
    @State private var runner: AutoClickerRunner
    @State private var navigation = Navigation()

    /// Held here so macro hotkeys live as long as the app, not as long as
    /// whichever view happened to register them.
    private let macroHotkeys: MacroHotkeyBinder

    init() {
        let permissions = PermissionManager()
        let eventTap = EventTapService()
        let watcher = WindowWatcher()
        let store = MacroStore()
        let engine = MacroEngine(executor: eventTap, watcher: watcher)
        let recorder = MacroRecorder()
        let hotkeys = HotkeyService()
        let emergency = EmergencyStopService()
        let runner = AutoClickerRunner(
            executor: eventTap,
            watcher: watcher,
            hotkeys: hotkeys,
            emergency: emergency
        )

        _permissions = State(initialValue: permissions)
        _eventTap = State(initialValue: eventTap)
        _watcher = State(initialValue: watcher)
        _store = State(initialValue: store)
        _engine = State(initialValue: engine)
        _recorder = State(initialValue: recorder)
        _hotkeys = State(initialValue: hotkeys)
        _emergency = State(initialValue: emergency)
        _runner = State(initialValue: runner)

        macroHotkeys = MacroHotkeyBinder(store: store, engine: engine, hotkeys: hotkeys)

        emergency.register(
            isActive: { [engine] in engine.isRunning },
            stop:     { [engine] in engine.stop() }
        )
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(permissions)
                .environment(eventTap)
                .environment(watcher)
                .environment(store)
                .environment(engine)
                .environment(recorder)
                .environment(hotkeys)
                .environment(emergency)
                .environment(runner)
                .environment(navigation)
                .environment(updates)
                .frame(minWidth: 1080, minHeight: 640)
                .task {
                    // Wait for the first window. Doing this in
                    // applicationDidFinishLaunching races SwiftUI's own
                    // window creation.
                    DockController.shared.apply(showInDock: DockController.defaultShowInDock)
                    updates.checkIfDue()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            // Settings is a sidebar section, so Cmd-, goes there instead of
            // opening a second window with the same content.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { navigation.section = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
