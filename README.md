# AeroCheat

macOS menu bar cheatsheet for [AeroSpace](https://github.com/nikitabobko/AeroSpace) shortcuts, with an active mode that suggests the keyboard shortcut when you switch workspace with the mouse.

This is a proof of concept: the menu bar app, the cheatsheet panel, and an active mode limited to mouse-driven workspace switches. The active mode has been unit-tested with synthetic and replayed event streams, but not yet verified by hand against a live AeroSpace.

## What it does

- Lives in the menu bar (no Dock icon). The menu offers **Show Cheatsheet**, **Reload AeroSpace Config**, the active mode controls (below) and **Quit AeroCheat**.
- A global hotkey toggles a floating cheatsheet panel above other windows. **Esc** or pressing the hotkey again closes it.
- The panel lists the bindings of your AeroSpace config, grouped by mode (`[mode.<name>.binding]`), with modifiers shown as ⌃ ctrl, ⌥ alt, ⇧ shift, ⌘ cmd. A search field filters by key, modifier name, or command.
- The config is read at launch (and on **Reload AeroSpace Config**) from `~/.aerospace.toml`, falling back to `~/.config/aerospace/aerospace.toml`. Symlinks are followed. The file is only ever read, never written.
- A missing or unparsable config shows a clear message in the panel instead of a list.

### Default hotkey

**⌃⌥⌘C** (ctrl + option + cmd + C). Three modifiers keep it clear of the usual AeroSpace bindings (`alt-…`, `alt-shift-…`, `ctrl-alt-…`). It is defined in one place: [`Sources/AeroCheat/HotkeyConfig.swift`](Sources/AeroCheat/HotkeyConfig.swift). If another app already owns the combo, the registration fails, a line is logged, and the menu bar item still works.

## Active mode

While active mode is on, AeroCheat notices when you switch workspace **with the mouse** (clicking a SketchyBar workspace item, or a Dock icon whose app lives on another workspace) and shows a small bubble at the top right of the screen, below the menu bar and SketchyBar, with the shortcut you could have used, for example "⌃⌥ 3 — switch to workspace 3". Modifier keys (control, option, shift, command) are drawn as their SF Symbol icons, other keys as keycap text. The shortcut comes from your own `[mode.main.binding]` table; if the config has no binding for that workspace, nothing is shown. For now every mouse-driven switch triggers a suggestion, including ones caused by a notification click.

Switching with the keyboard (your AeroSpace bindings), with Cmd-Tab, or through Spotlight or a script never triggers a suggestion.

### How to try it

1. Make sure AeroSpace 0.21.0-Beta or newer is running (`aerospace --version`).
2. `swift run AeroCheat`, then open the menu bar item and tick **Active Mode**. It is off by default; the choice is saved in `UserDefaults`.
3. Click a workspace item in your bar, or a Dock icon of an app on another workspace. The bubble appears within a fraction of a second and stays for 4 seconds, then fades.
4. Press the suggested shortcut instead: no bubble, and that shortcut is muted for the rest of the day.

The menu shows the connection state (for example "AeroSpace not found", "AeroSpace 0.20.x is too old" or "AeroSpace is not running, retrying…"), a **Last suggestion** line and **Snooze Suggestions for 1 Hour**. The connection is re-established with a growing delay if AeroSpace exits or restarts.

To keep it quiet: the same suggestion repeats at most every 30 s, at most one bubble appears every 5 s, a shortcut you press after a suggestion is muted for the day, and a suggestion ignored three times is muted for the day too.

### How it works, and why it needs no permission

AeroCheat runs `aerospace subscribe --no-send-initial focus-changed focused-workspace-changed binding-triggered mode-changed` as a child process (found in `/opt/homebrew/bin`, `/usr/local/bin`, then `PATH`) and reads its JSON events. AeroSpace emits `binding-triggered` whenever a keyboard binding fires, so a workspace change that arrives without one did not come from your AeroSpace shortcuts. Events less than about 120 ms apart form a burst; a burst with a binding is keyboard and ignored, a burst with a net workspace change and no binding is a candidate. It becomes a mouse action only if the left mouse button went down or up within the last 0.8 s, read with `CGEventSource.secondsSinceLastEventType`.

None of this needs Accessibility, Input Monitoring or Screen Recording: the event stream is a user-level socket behind the `aerospace` CLI, and the click recency counters are not privacy-gated. AeroCheat does not use an event tap or a global `NSEvent` monitor, and it does not post system notifications. It only runs read-only `aerospace` commands (`--version`, `subscribe`) and changes nothing in your AeroSpace or SketchyBar configuration.

Out of scope for now: click-to-focus, drag and resize hints, Cmd-Tab suggestions, filtering notification clicks from Dock clicks, binding modes other than `main`, and multiple monitors.

## Build and run

Requires macOS 13+ and a Swift 5.9+ toolchain (Xcode or Command Line Tools).

```sh
swift build            # debug build
swift run AeroCheat    # launch; look for the keyboard icon in the menu bar
swift test             # unit tests
```

For a release binary: `swift build -c release`, then run `.build/release/AeroCheat`.

### Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs `swift build` and `swift test` on a GitHub-hosted macOS runner for pull requests and pushes to `main`. It is gated to public repositories (a skipped job starts no runner and costs nothing), so it does nothing while this repository is private. Once the repository is public it runs on its own; to run it by hand, use the **Actions** tab (**CI** → **Run workflow**) or `gh workflow run ci.yml`.

## Permissions

None. The hotkey uses the Carbon `RegisterEventHotKey` API, which needs neither Accessibility nor Input Monitoring, and active mode is permission-free too (see above). The app does not touch the network and reads only your AeroSpace config.

## Layout

| Path | Role |
|------|------|
| `Sources/AeroCheatCore` | UI-free logic: minimal TOML reader, AeroSpace binding parser, key formatting, search filter; active mode event model, burst classifier, action resolver, suggestion policy |
| `Sources/AeroCheat` | Menu bar app: status item, global hotkey, floating panel, SwiftUI view; active mode event stream, mouse recency probe, toast panel |
| `Tests/AeroCheatCoreTests` | Unit tests, using `Fixtures/sample-aerospace.toml` and a sanitised `golden-replay.jsonl` rather than a real config or capture |
