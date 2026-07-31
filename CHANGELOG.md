# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-07-31

### Fixed

- Exporting wrote files called `name.mimicdeck.json`. The save panel enforces
  its allowed content type, so the suggested `.mimicdeck` extension was only
  ever appended to, never used. Exports are now plain `.json`, which is what
  the format has always been. Files written by 1.0.0 still import fine.
- The import panel said "Choose an MimicDeck macro file", left over from the
  rename.
- The project relied on `SWIFT_DEFAULT_ACTOR_ISOLATION` to put `AppDelegate`
  on the main actor. Xcode 16 ignores that setting, so building from source
  failed there while succeeding on Xcode 26. Isolation is now spelled out in
  the code and no longer depends on the toolchain version.

## [1.0.0] - 2026-07-31

First public release.

### Added

- **Auto Clicker.** Left / right / middle click loop with a fixed or random
  interval, fired at the cursor or at a pinned screen point.
- **Trigger modes.** Toggle (press to start, press again to stop) and Hold
  (clicks while the combo is held).
- **Stop limits.** After a click count, after a time limit, or when the
  frontmost app changes. Any combination; whichever hits first wins.
- **Macro recorder.** Captures clicks and key presses through a listen-only
  event tap and reproduces the original timing on playback. Consecutive
  keystrokes collapse into a single readable "type text" step.
- **Macro editor.** Inline editing, reordering and deletion of steps, plus
  manual click / key / wait / typed text / cursor move steps.
- **Window binding.** A macro can be bound to an app by bundle identifier and
  pauses automatically whenever that app is not frontmost.
- **Global hotkeys.** Per-macro and per-clicker combos that work from any app.
- **Emergency stop.** Opt-in global panic key that stops anything running.
- **Import / export.** Macros travel as JSON bundles.
  Importing shows what is in the file first, and says plainly when the macro
  presses keys and types text rather than only clicking.
- **Menu bar mode.** Hide the Dock icon and drive the app from a status item.
- **Update check.** Optional daily look at the GitHub releases API. It opens
  the download page in a browser and never downloads or installs anything.
  Switching it off in Settings stops every network request the app makes.
- **Onboarding.** First-launch permission flow with live status detection for
  Accessibility, no restart required.
- Launch at login, light / dark / system appearance, MIT license, CI running
  build and unit tests on every push.

### Fixed

- A stopped-then-restarted clicker could orphan its live task: the app
  reported "not running" while it kept clicking, and neither the Stop button,
  the hotkey nor the emergency stop could reach it. Runs are now generation
  tagged so a finishing loop can never clear a newer one's state.
- Navigating away from the Auto Clicker screen tore down the view while its
  click loop kept running, leaving no way to stop it. The loop, its
  configuration and its hotkey now live in a service that outlives the view.
- A macro's hotkey only worked while that macro happened to be open in the
  editor, and it fired against the macro as it looked at registration time,
  so steps added afterwards were ignored. Hotkeys are now registered app-wide
  and resolve the macro at fire time.
- Fixed click positions were computed against the height of whichever display
  the cursor was over instead of the primary display, so every click landed
  off target on multi-monitor setups with differing heights or offsets.
- Edits made in the last 250 ms before quitting were lost to the save
  debounce. Macros now flush synchronously on termination.
- A stored interval of 0 ms turned the click loop into a busy spin that
  starved the main actor and made Stop unresponsive.
- "Stop on window change" triggered immediately when started from the run bar,
  because MimicDeck itself was recorded as the baseline app.
- A failed Launch at Login change was swallowed silently. It now logs, reports
  the reason, and reverts the switch.
- Quitting from onboarding called `exit(0)`, skipping app teardown. It now
  drops the sheet first and terminates properly, because a window with a sheet
  attached refuses to close and leaves the quit hanging.
- The macro editor could reorder and delete steps but not duplicate one.
- The macro list had no way to filter by name.
- Import accepted any file: no size ceiling, and a bundle claiming a newer
  format version was decoded anyway instead of being refused.

### Changed

- Minimum supported macOS lowered from 26.3 to 14.0 (Sonoma).
- Built in Swift 6 language mode with strict concurrency checking.
- Cmd-, navigates to the Settings section instead of opening a second window
  showing the same screen.
