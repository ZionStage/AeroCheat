import AeroCheatCore
import AppKit
import SwiftUI

/// The settings window's content: position, look, timing and behaviour of the suggestion bubble. It only
/// edits `DisplaySettingsModel`, which clamps, saves and applies every change at once.
public struct SettingsView: View {
    @ObservedObject var model: DisplaySettingsModel
    let onPreview: () -> Void

    public init(model: DisplaySettingsModel, onPreview: @escaping () -> Void) {
        self.model = model
        self.onPreview = onPreview
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
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
