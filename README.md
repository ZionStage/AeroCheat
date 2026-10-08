<p align="center">
  <img src="Assets/AppIcon.png" alt="AeroCheat logo: a folded crib note with the Command symbol" width="96">
</p>

# AeroCheat

A small macOS menu bar app that shows the shortcuts of your [AeroSpace](https://github.com/nikitabobko/AeroSpace) config, and nudges you toward the keyboard when you reach for the mouse.

- **Cheatsheet.** A global hotkey opens a searchable panel with the bindings of your AeroSpace config, grouped by category; with Active Mode on, it also marks the shortcuts you rarely press.
- **Suggestions.** After you switch workspace or window with the mouse, a small bubble shows the shortcut you could have used.
- **Settings.** Choose the cheatsheet hotkey, where the bubble appears, its colours and how long it stays.

## Requirements

- macOS 13 or newer.
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) with a config file. Suggestions need AeroSpace 0.21.0 or newer; the cheatsheet works with any version.
- No macOS permission to grant: AeroCheat asks for no Accessibility, Input Monitoring or Screen Recording access.

## Install

1. Download the latest `.dmg` from the [Releases page](https://github.com/ZionStage/AeroCheat/releases/latest) and open it.
2. Drag **AeroCheat** onto the **Applications** folder.
3. The app is not notarised (there is no paid Apple Developer account behind it), so macOS asks for confirmation once: right-click the app, choose **Open**, then confirm.

Look for the icon in the menu bar; there is no Dock icon.

To build it yourself, clone the repository and run `scripts/build-app.sh`. It produces `dist/AeroCheat.app`, plus a `.dmg` and a `.zip`.

## Use

Press **⌃⌥⌘C** (or the hotkey you set in Settings) to open or close the cheatsheet (Esc also closes it).

The menu bar menu lets you show the cheatsheet, reload the config, turn **Active Mode** on (suggestions are off by default), snooze suggestions, open Settings, switch **Launch at Login** on or off, and quit.

With Active Mode on, clicking over to workspace 3 with the mouse while your config has `alt-3 = 'workspace 3'` shows a bubble such as "⌥ 3 — switch to workspace 3".

The Settings window sets the cheatsheet hotkey, the bubble position, colours and timing, and the path of your AeroSpace config. By default AeroCheat reads `~/.aerospace.toml`, then `~/.config/aerospace/aerospace.toml`.

If the menu says AeroSpace is not running or too old, start it or update it to 0.21.0 or newer.

## Limits

- It guesses whether a change came from the mouse, and can be wrong: a Dock click can trigger a suggestion.
- Only the `main` binding mode and a single display are handled.
- Your AeroSpace config is only read, never written.
- No network access and no telemetry.

## Uninstall

Quit AeroCheat from its menu, then drag it from Applications to the Trash.
To forget its settings too: `defaults delete io.github.zionstage.AeroCheat`

## Licence

MIT, see [`LICENSE`](LICENSE).
