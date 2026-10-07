<p align="center">
  <img src="Assets/AppIcon.png" alt="AeroCheat logo: a folded crib note with the Command symbol" width="128">
</p>

# AeroCheat

A macOS menu bar app that shows the keyboard shortcuts of your [AeroSpace](https://github.com/nikitabobko/AeroSpace) config and, when you switch workspace or window with the mouse, suggests the shortcut you could have used.

## What it does

- **Cheatsheet panel.** A global hotkey opens a floating, searchable list of the bindings in your AeroSpace config.
- **Active mode.** Optional. After a mouse-driven workspace switch or window change, a small bubble shows the matching shortcut from your config.
- **Settings window.** Moves and restyles the bubble, tunes how often it appears, and points the app at a non-default AeroSpace config.

This is a proof of concept. Active mode is covered by unit tests on synthetic and replayed event streams; it has not been verified by hand against every AeroSpace setup, so expect rough edges (see [How it works](#how-it-works-and-its-limits)).

## Requirements

- macOS 13 or newer (`platforms: [.macOS(.v13)]` in `Package.swift`).
- A Swift 5.9+ toolchain: Xcode, or the command line tools (`xcode-select --install`). Only needed to build from source.
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) with a config file. The cheatsheet works with any version. **Active mode needs AeroSpace 0.21.0 or newer**, the first version with `aerospace subscribe`; the app checks `aerospace --version` and says so in its menu if yours is older.
- No macOS permission: no Accessibility, Input Monitoring or Screen Recording prompt. The hotkey uses the Carbon `RegisterEventHotKey` API, and active mode only reads the output of the `aerospace` command-line tool. Nothing in the sources uses an event tap, a global event monitor, screen capture, notifications or the network.

## Install and run

Clone the repository first:

```sh
git clone https://github.com/ZionStage/AeroCheat.git
cd AeroCheat
```

### 1. Run from source

```sh
swift run AeroCheat
```

The first run compiles the app. The terminal stays attached; stop it with `Ctrl-C` or **Quit AeroCheat** in the menu.

### 2. Build a release binary

```sh
swift build -c release
```

The binary is `.build/release/AeroCheat` (a single executable, about 1.3 MB). To put it on your `PATH`:

```sh
mkdir -p ~/.local/bin
cp .build/release/AeroCheat ~/.local/bin/
```

Make sure `~/.local/bin` is in your `PATH`, or use another folder that is (for example `/usr/local/bin`, which may need `sudo`). Then start it from any terminal:

```sh
AeroCheat &
```

AeroCheat is a menu bar app: it has no Dock icon and no window at launch. Look for the crib-note icon in the menu bar.

### 3. Start at login

A bare executable is not an app bundle, so the simplest way is a LaunchAgent that you create yourself. This writes one for the binary installed in `~/.local/bin` above (the shell expands `$HOME`, because launchd does not expand `~`):

```sh
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/local.aerocheat.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>local.aerocheat</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.local/bin/AeroCheat</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF
```

Load it (it also starts at every login), and unload it to stop and disable it:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.aerocheat.plist
launchctl bootout gui/$(id -u)/local.aerocheat
```

The plist syntax was checked with `plutil -lint`. The `launchctl` commands were not run while writing this README, so check `launchctl list | grep aerocheat` after loading. The app looks for `aerospace` in `/opt/homebrew/bin` and `/usr/local/bin` before `PATH`, so the minimal environment of a LaunchAgent is not a problem for Homebrew installs.

Alternative: **System Settings → General → Login Items & Extensions** lets you add a file with the **+** button. Whether macOS runs a bare executable from there without opening a Terminal window was **not checked**; prefer the LaunchAgent.

### 4. App bundle

A `.app` bundle is not provided yet: the repository has no `Info.plist` or packaging script, and `Assets/AppIcon.icns` is not wired into anything. Use one of the options above.

## Usage

### Menu bar menu

| Item | What it does |
|------|--------------|
| Show Cheatsheet | Opens the panel. |
| Reload AeroSpace Config | Re-reads the config. The file is not watched, so use this after editing it. |
| Hotkey: ⌃⌥⌘C | Reminder of the hotkey (or "Hotkey unavailable", see [Troubleshooting](#troubleshooting)). |
| Active Mode | Tick to turn active mode on. Off by default; the choice is remembered. |
| (status line) | "Active mode is off", "Connecting to AeroSpace…", "Watching for mouse workspace switches", "AeroSpace not found…", "AeroSpace x.y.z is too old…" or "AeroSpace is not running, retrying…". |
| Last suggestion | The last bubble shown, or "none yet". |
| Snooze Suggestions for 1 Hour | Silences bubbles for an hour; the item becomes "Resume Suggestions". |
| Settings… (⌘,) | Opens the settings window. |
| Quit AeroCheat (⌘Q) | Quits. |

### Cheatsheet panel

The default global hotkey is **⌃⌥⌘C** (ctrl + option + cmd + C). It is defined in [`Sources/AeroCheat/HotkeyConfig.swift`](Sources/AeroCheat/HotkeyConfig.swift); to change it, edit that file and rebuild. The hotkey toggles the panel; **Esc** also closes it.

The panel lists the bindings of the `[mode.<name>.binding]` tables of your config, one section per mode, with modifiers shown as ⌃ ctrl, ⌥ alt, ⇧ shift, ⌘ cmd. The search field has focus when the panel opens and filters by key, modifier name or command. The footer shows which config file is in use. If the config is missing or cannot be parsed, the panel says so instead of showing a list.

### Active mode

Tick **Active Mode** in the menu. AeroCheat then watches for two kinds of mouse action and shows a bubble (by default at the top right of the screen, for 4 seconds) with the shortcut from your `[mode.main.binding]` table:

- **Workspace switch** with the mouse, for example clicking a workspace item in a bar, or a window of another workspace in Mission Control. With a binding `alt-3 = 'workspace 3'` you get a bubble such as "⌥ 3 — switch to workspace 3". If you land back on the previous workspace and you have a `workspace-back-and-forth` binding, the bubble adds "or … to toggle back".
- **Focus change inside a workspace** by clicking another window of it. The bubble suggests your `focus left` / `focus right` (horizontal layouts) or `focus up` / `focus down` (vertical layouts) binding.

Nothing is shown when your config has no matching binding, when you used the keyboard, or when AeroCheat cannot tell it was a mouse action. Only the `main` mode is considered.

Quiet defaults (all adjustable in the settings):

- the same suggestion repeats at most every 30 s, and at most one bubble appears every 5 s;
- if you press the suggested shortcut afterwards, it is muted for the rest of the day;
- a suggestion you ignore three times (60 s without using the shortcut counts as ignored) is muted for the rest of the day.

### Demo mode

```sh
swift run AeroCheat --demo
# or, with a built binary:
AeroCheat --demo
```

Plays a built-in script of about 35 seconds instead of the real AeroSpace stream: a mouse switch (bubble), a keyboard switch (nothing), the same mouse switch again (rate limited), then two more switches, the last with the toggle-back hint. Active mode starts on; untick and tick it to replay. Demo mode does not start `aerospace subscribe`, uses a built-in sample config instead of yours, and does not save settings changes (it does read your saved bubble look). The script is `Sources/AeroCheatCore/DemoScript.swift`.

### Settings window

Every change applies at once and is saved. **Preview** shows the bubble with the current settings; **Reset to defaults** restores the bubble settings (the config path is managed in its own section).

| Section | What you can set |
|---------|------------------|
| AeroSpace config | A path to your config (type it and press Return, or **Choose…**). **Use default location** goes back to the automatic search. Shows the file in use and how many bindings were found, or the error. |
| Position | Where the bubble sits on a 3×3 grid (corners, edge middles, centre; default top right). Horizontal and vertical margins (default 16 pt and 80 pt, 0–400 pt), ignored along a centred axis. |
| Look | Background, text and icon/key colours (system look or a picked colour), opacity (30–100 %), size (75–175 %), how long it stays (1–30 s, default 4). |
| Delays | Minimum time between two bubbles (0–600 s, default 5) and between two identical bubbles (0–3600 s, default 30). |
| Content | Modifier keys as icons or as text; which kinds of suggestions are on (workspace switches, window focus). |

**Config path.** The automatic search reads `~/.aerospace.toml`, then `~/.config/aerospace/aerospace.toml`, the first that exists. A custom path may start with `~`, be relative to your home folder, or go through a symlink. A custom path is never mixed with the automatic search: if the file is missing, is a folder, is unreadable, is not UTF-8 or is not valid TOML, you get that error in the settings and the panel, not the default config.

## How it works, and its limits

- AeroCheat **only reads** your AeroSpace config (a small built-in TOML reader looks at the `[mode.*.binding]` tables). It never writes it, and it runs only read-only `aerospace` commands: `--version`, `subscribe` and `list-windows`.
- Active mode starts `aerospace subscribe --no-send-initial focus-changed focused-workspace-changed binding-triggered mode-changed` as a child process and reads its events. AeroSpace reports a `binding-triggered` event when a keyboard binding fires, so a workspace or focus change that arrives without one did not come from your shortcuts. If, in addition, the left mouse button went down or up in the last 0.8 s and no key was pressed after it (read with `CGEventSource.secondsSinceLastEventType`, which needs no permission), the change is taken as a mouse action.
- No network access and no telemetry. The only data kept is your settings in `UserDefaults`.
- It guesses, and the guess can be wrong. Known limits:
  - a click on a Dock icon or a menu item that raises another window of the same workspace looks like a window click and may produce a focus suggestion;
  - every mouse-driven workspace switch can trigger a suggestion, including one caused by clicking a notification or opening an app that lives on another workspace;
  - a click directly on a visible tiled window is deliberately silent;
  - in accordion layouts, a click that closes or opens a window can look like an indirect click;
  - Cmd-Tab, Spotlight and scripts are never suggested; only the `main` binding mode and a single display are handled.

## Troubleshooting

- **"AeroSpace not found" / "AeroSpace is not running, retrying…" in the menu.** Install AeroSpace and start it. The app searches `/opt/homebrew/bin`, `/usr/local/bin`, then `PATH`, and retries with a growing delay.
- **"AeroSpace x.y.z is too old".** Update AeroSpace to 0.21.0 or newer (`aerospace --version`).
- **"AeroSpace config not found" or "Cannot read the AeroSpace config".** Check the file exists at one of the two default paths, or set its path in **Settings… → AeroSpace config**. The message in the panel and the settings names the path and the reason (for example a TOML syntax error). After editing the file, use **Reload AeroSpace Config**.
- **The panel says "No bindings found".** The config has no `[mode.<name>.binding]` table.
- **The hotkey does nothing / the menu says "Hotkey unavailable".** Another app owns ⌃⌥⌘C. The failure is logged (`AeroCheat: could not register the global hotkey`), and the menu item still works. Free the combination, or change it in `HotkeyConfig.swift` and rebuild.
- **No bubble appears.**
  - Is **Active Mode** ticked and the status "Watching for mouse workspace switches"?
  - Does your config's `[mode.main.binding]` have a binding for that workspace (or a `focus` binding)?
  - Is the bubble snoozed, muted for the day, or inside a cooldown? Lower the delays in **Delays**.
  - Is that kind of suggestion switched off in **Content**?
  - Try `AeroCheat --demo` to check that the bubble itself shows.
- **Reset the settings.** Quit the app, then delete its `UserDefaults` domain (a bare executable uses its name as the domain; keys are `activeModeEnabled`, `config.path` and `display.*`):

  ```sh
  defaults delete AeroCheat
  ```

## Uninstall

1. Stop the app: **Quit AeroCheat** in the menu, or `pkill -x AeroCheat`.
2. Remove the start-at-login agent, if you created one:

   ```sh
   launchctl bootout gui/$(id -u)/local.aerocheat
   rm ~/Library/LaunchAgents/local.aerocheat.plist
   ```

3. Remove the binary: `rm ~/.local/bin/AeroCheat` (or wherever you put it).
4. Delete the settings: `defaults delete AeroCheat`.

Your AeroSpace config is never modified, so there is nothing to restore.

## Development

```sh
swift build   # debug build
swift test    # unit tests, including offscreen rendering of the bubble
```

The sources are organised as three targets:

- `Sources/AeroCheatCore`: UI-free logic (TOML reader, binding parser, key formatting, search filter, active-mode event model and classifier, suggestion policy, settings and their storage, config path handling, demo script).
- `Sources/AeroCheatUI`: the suggestion bubble, the menu bar logo, the settings models and the settings view.
- `Sources/AeroCheat`: the menu bar app (status item, hotkey, panel, `aerospace subscribe` process, mouse probe, toast, settings window).

Tests are in `Tests/AeroCheatCoreTests` and `Tests/AeroCheatUITests`.

The logo is drawn by a script that rewrites `Assets/AppIcon.png`, `Assets/AppIcon.icns`, the menu bar glyphs and the embedded glyph data; run it from the repository root:

```sh
swift scripts/render-logo.swift
```

The GitHub workflow (`.github/workflows/ci.yml`) builds and tests on a macOS runner for pull requests and pushes to `main`. It runs only on public repositories; on a private one the job is skipped.

## Licence

MIT, see [`LICENSE`](LICENSE).
