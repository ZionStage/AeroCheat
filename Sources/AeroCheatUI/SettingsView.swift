import AeroCheatCore
import AppKit
import SwiftUI

/// The settings window's content: the cheatsheet hotkey, then the position, look, timing and behaviour of the
/// suggestion bubble. It only edits the models, which check, save and apply every change at once.
public struct SettingsView: View {
    @ObservedObject var model: DisplaySettingsModel
    @ObservedObject var configSource: ConfigSourceModel
    @ObservedObject var hotkey: HotkeySettingsModel
    let onPreview: () -> Void
    /// What the path field shows while it is being edited; applied on Return or when the field loses focus.
    @State private var pathDraft = ""
    @FocusState private var pathFocused: Bool

    public init(
        model: DisplaySettingsModel,
        configSource: ConfigSourceModel,
        hotkey: HotkeySettingsModel = HotkeySettingsModel(storage: nil),
        onPreview: @escaping () -> Void
    ) {
        self.model = model
        self.configSource = configSource
        self.hotkey = hotkey
        self.onPreview = onPreview
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                hotkeySection
                configSection
                positionSection
                lookSection
                timingSection
                contentSection
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Button("Reset to defaults") { model.resetToDefaults() }
                Spacer()
                Button("Preview", action: onPreview).keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 440, minHeight: 560)
    }

    // MARK: Sections

    private var hotkeySection: some View {
        Section("Cheatsheet hotkey") {
            HStack {
                Text("Opens and closes the cheatsheet")
                Spacer()
                HotkeyRecorder(model: hotkey)
                Button("Default") { hotkey.resetToDefault() }
                    .disabled(hotkey.hotkey == .default)
            }
            if let problem = hotkey.problem {
                Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            Text("Click the shortcut, then press the new combination with at least one of ⌃, ⌥ or ⌘. Esc cancels.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var configSection: some View {
        Section("AeroSpace config") {
            HStack {
                TextField("Path", text: $pathDraft, prompt: Text("Automatic: ~/.aerospace.toml"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .focused($pathFocused)
                    .onSubmit(commitPath)
                Button("Choose…", action: chooseConfigFile)
                Button("Use default location") {
                    configSource.useDefaultLocation()
                    pathDraft = ""
                }
                .disabled(configSource.setting == .automatic && pathDraft.isEmpty)
            }
            .onAppear { pathDraft = configSource.setting.text }
            .onChange(of: pathFocused) { focused in if !focused { commitPath() } }
            .onChange(of: configSource.setting) { pathDraft = $0.text }
            LabeledContent("In use") {
                Text(effectivePathText).textSelection(.enabled).lineLimit(2).truncationMode(.middle)
            }
            Label(loadStatusText, systemImage: configSource.result.bindingCount == nil ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(configSource.result.bindingCount == nil ? Color.orange : Color.secondary)
                .textSelection(.enabled)
            Text("Empty uses the automatic search: ~/.aerospace.toml, then ~/.config/aerospace/aerospace.toml. A path may start with ~ or be relative to your home folder, and may go through a symlink. The file is only read, never written.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var positionSection: some View {
        Section("Position") {
            HStack(alignment: .center, spacing: 16) {
                anchorGrid
                Text("\(model.settings.anchor.title) of the screen. The margins keep the bubble clear of the menu bar, SketchyBar and window buttons; the centre row and column ignore them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            numberRow("Horizontal margin", $model.settings.horizontalMargin, DisplaySettings.marginRange, unit: "pt", step: 4,
                      disabled: model.settings.anchor.horizontal == .middle)
            numberRow("Vertical margin", $model.settings.verticalMargin, DisplaySettings.marginRange, unit: "pt", step: 4,
                      disabled: model.settings.anchor.vertical == .middle)
        }
    }

    private var lookSection: some View {
        Section("Look") {
            colorRow("Background", \.backgroundColor, system: Color(nsColor: .windowBackgroundColor))
            colorRow("Text", \.textColor, system: Color(nsColor: .labelColor))
            colorRow("Icons and keys", \.iconTint, system: Color(nsColor: .labelColor))
            sliderRow("Opacity", $model.settings.opacity, DisplaySettings.opacityRange)
            sliderRow("Size", $model.settings.scale, DisplaySettings.scaleRange)
            numberRow("Stays for", $model.settings.duration, DisplaySettings.durationRange, unit: "s", step: 0.5)
        }
    }

    private var timingSection: some View {
        Section("Delays") {
            numberRow("Between two tips", $model.settings.tipInterval, DisplaySettings.tipIntervalRange, unit: "s", step: 1)
            numberRow("Between two identical tips", $model.settings.identicalTipInterval, DisplaySettings.identicalTipIntervalRange, unit: "s", step: 5)
        }
    }

    private var contentSection: some View {
        Section("Content") {
            Picker("Modifier keys", selection: $model.settings.iconsForModifiers) {
                Text("Icons").tag(true)
                Text("Text").tag(false)
            }
            .pickerStyle(.segmented)
            ForEach(SuggestionKind.allCases, id: \.self) { kind in
                Toggle(isOn: SwiftUI.Binding(
                    get: { model.settings.isEnabled(kind) },
                    set: { model.settings.setEnabled(kind, $0) }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(kind.title)
                        Text(kind.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Config path

    private func commitPath() {
        let setting = ConfigPathSetting(text: pathDraft)
        if setting != configSource.setting { configSource.setPath(pathDraft) }
    }

    private var effectivePathText: String {
        switch configSource.result {
        case .loaded(let path, _): return path
        case .failed(let path, _): return path.isEmpty ? "—" : path
        case .missing(let searched): return "None found (looked in " + searched.joined(separator: ", ") + ")"
        }
    }

    private var loadStatusText: String {
        switch configSource.result {
        case .loaded(_, let modes):
            let count = configSource.result.bindingCount ?? 0
            return "\(count) binding\(count == 1 ? "" : "s") in \(modes.count) mode\(modes.count == 1 ? "" : "s")"
        case .failed(_, let message): return message
        case .missing: return "No AeroSpace config found at the default locations."
        }
    }

    /// Any file can be picked (`.toml` is what AeroSpace uses, but it is not required); hidden files are shown
    /// because `~/.aerospace.toml` is one.
    private func chooseConfigFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose your AeroSpace config"
        panel.message = "Usually aerospace.toml or .aerospace.toml"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if let current = configSource.result.effectivePath {
            panel.directoryURL = URL(fileURLWithPath: current).deletingLastPathComponent()
        } else {
            panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pathDraft = url.path
        configSource.setPath(url.path)
    }

    // MARK: Controls

    /// The screen as the 3x3 grid of anchors, laid out like the places on the screen.
    private var anchorGrid: some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            ForEach(Array(BubbleAnchor.grid.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row, id: \.self) { anchor in
                        let selected = model.settings.anchor == anchor
                        Button { model.settings.anchor = anchor } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selected ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: 30, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help(anchor.title)
                        .accessibilityLabel(anchor.title)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.5)))
    }

    private func numberRow(
        _ title: String, _ value: SwiftUI.Binding<Double>, _ range: ClosedRange<Double>, unit: String, step: Double, disabled: Bool = false
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...1)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            Text(unit).foregroundStyle(.secondary).frame(width: 18, alignment: .leading)
            Stepper(title, value: value, in: range, step: step).labelsHidden()
        }
        .disabled(disabled)
    }

    private func sliderRow(_ title: String, _ value: SwiftUI.Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range)
            Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    /// A switch between the system look (`nil`) and a picked colour.
    private func colorRow(_ title: String, _ keyPath: WritableKeyPath<DisplaySettings, SettingsColor?>, system: Color) -> some View {
        let custom = model.settings[keyPath: keyPath]
        return HStack {
            Toggle(title, isOn: SwiftUI.Binding(
                get: { model.settings[keyPath: keyPath] != nil },
                set: { model.settings[keyPath: keyPath] = $0 ? SettingsColor(system) : nil }
            ))
            Spacer()
            if custom == nil {
                Text("System").foregroundStyle(.secondary)
            }
            ColorPicker(title, selection: SwiftUI.Binding(
                get: { model.settings[keyPath: keyPath]?.color ?? system },
                set: { model.settings[keyPath: keyPath] = SettingsColor($0) }
            ), supportsOpacity: false)
                .labelsHidden()
                .disabled(custom == nil)
        }
    }
}

/// Shows the hotkey; once clicked, the next key press in this window becomes the new one (Esc alone cancels).
/// A local event monitor only sees keys sent to AeroCheat's own windows, so it needs no permission.
private struct HotkeyRecorder: View {
    @ObservedObject var model: HotkeySettingsModel
    @State private var monitor: Any?
    @State private var observers: [NSObjectProtocol] = []

    var body: some View {
        Button(monitor == nil ? model.hotkey.display : "Press a shortcut…") {
            monitor == nil ? start() : stop()
        }
        .font(.body.monospaced())
        .frame(minWidth: 140)
        .onDisappear(perform: stop)
    }

    private func start() {
        guard let window = NSApp.keyWindow else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window === window else { return event }
            let modifiers = Self.modifiers(event.modifierFlags)
            if event.keyCode == 53, modifiers.isEmpty {
                stop()
            } else if model.record(keyCode: UInt32(event.keyCode), modifiers: modifiers) {
                stop()
            }
            return nil
        }
        observers = [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification].map {
            NotificationCenter.default.addObserver(forName: $0, object: window, queue: .main) { _ in stop() }
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    private static func modifiers(_ flags: NSEvent.ModifierFlags) -> Set<Modifier> {
        var result: Set<Modifier> = []
        if flags.contains(.control) { result.insert(.ctrl) }
        if flags.contains(.option) { result.insert(.alt) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.cmd) }
        return result
    }
}
