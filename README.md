# AeroCheat

macOS menu bar cheatsheet for [AeroSpace](https://github.com/nikitabobko/AeroSpace) shortcuts, with an active mode (planned) that suggests the keyboard shortcut when you use the mouse.

This is the proof-of-concept foundation: the menu bar app and the cheatsheet panel. The active mouse-detection mode is not implemented yet.

## What it does

- Lives in the menu bar (no Dock icon). The menu offers **Show Cheatsheet**, **Reload AeroSpace Config** and **Quit AeroCheat**.
- A global hotkey toggles a floating cheatsheet panel above other windows. **Esc** or pressing the hotkey again closes it.
- The panel lists the bindings of your AeroSpace config, grouped by mode (`[mode.<name>.binding]`), with modifiers shown as ⌃ ctrl, ⌥ alt, ⇧ shift, ⌘ cmd. A search field filters by key, modifier name, or command.
- The config is read at launch (and on **Reload AeroSpace Config**) from `~/.aerospace.toml`, falling back to `~/.config/aerospace/aerospace.toml`. Symlinks are followed. The file is only ever read, never written.
- A missing or unparsable config shows a clear message in the panel instead of a list.

### Default hotkey

**⌃⌥⌘C** (ctrl + option + cmd + C). Three modifiers keep it clear of the usual AeroSpace bindings (`alt-…`, `alt-shift-…`, `ctrl-alt-…`). It is defined in one place: [`Sources/AeroCheat/HotkeyConfig.swift`](Sources/AeroCheat/HotkeyConfig.swift). If another app already owns the combo, the registration fails, a line is logged, and the menu bar item still works.

## Build and run

Requires macOS 13+ and a Swift 5.9+ toolchain (Xcode or Command Line Tools).

```sh
swift build            # debug build
swift run AeroCheat    # launch; look for the keyboard icon in the menu bar
swift test             # unit tests
```

For a release binary: `swift build -c release`, then run `.build/release/AeroCheat`.

## Permissions

None. The hotkey uses the Carbon `RegisterEventHotKey` API, which needs neither Accessibility nor Input Monitoring. The app does not touch the network and reads only your AeroSpace config. (The future active mode will need Accessibility.)

## Layout

| Path | Role |
|------|------|
| `Sources/AeroCheatCore` | UI-free logic: minimal TOML reader, AeroSpace binding parser, key formatting, search filter |
| `Sources/AeroCheat` | Menu bar app: status item, global hotkey, floating panel, SwiftUI view |
| `Tests/AeroCheatCoreTests` | Unit tests, using `Fixtures/sample-aerospace.toml` rather than a real config |
