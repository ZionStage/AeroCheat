import Carbon.HIToolbox

/// The global shortcut that toggles the cheatsheet. Change it here only.
///
/// ⌃⌥⌘C: three modifiers plus a letter, so it stays clear of the usual AeroSpace
/// bindings (alt-, alt-shift- or ctrl-alt- plus a key). Carbon hotkeys need no
/// Accessibility or Input Monitoring permission.
enum HotkeyConfig {
    static let keyCode = UInt32(kVK_ANSI_C)
    static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    /// Shown in the menu bar menu and the panel footer.
    static let display = "⌃⌥⌘C"
}
