import AppKit

let app = NSApplication.shared
// `--demo` plays scripted fixture events instead of reading the real AeroSpace session (see README).
let delegate = AppDelegate(demo: CommandLine.arguments.contains("--demo"))
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
