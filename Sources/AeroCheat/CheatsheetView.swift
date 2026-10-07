import AeroCheatCore
import SwiftUI

/// What the panel shows; `ConfigSourceModel` loads the config and pushes each result here.
final class CheatsheetModel: ObservableObject {
    @Published var result: ConfigLoadResult
    @Published var query = ""
    /// Bumped every time the panel is shown so the search field grabs focus again.
    @Published var focusToken = 0

    init(result: ConfigLoadResult) {
        self.result = result
    }
}

struct CheatsheetView: View {
    @ObservedObject var model: CheatsheetModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 560, height: 520)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { _ in searchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Filter by key or command", text: $model.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($searchFocused)
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        switch model.result {
        case .loaded(_, let modes):
            let filtered = BindingFilter.apply(model.query, to: modes)
            if filtered.isEmpty {
                message(
                    title: modes.isEmpty ? "No bindings found" : "No match",
                    detail: modes.isEmpty
                        ? "The config has no [mode.*.binding] table."
                        : "Nothing matches “\(model.query)”."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
                        ForEach(filtered) { mode in
                            ModeSection(mode: mode)
                        }
                    }
                    .padding(16)
                }
            }
        case .missing(let searched):
            message(
                title: "AeroSpace config not found",
                detail: "Looked for:\n" + searched.joined(separator: "\n")
            )
        case .failed(let path, let reason):
            message(title: "Cannot read the AeroSpace config", detail: "\(path)\n\n\(reason)")
        }
    }

    private func message(title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if case .loaded(let path, _) = model.result {
                Text(path).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text("esc or \(HotkeyConfig.display) to close")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct ModeSection: View {
    let mode: BindingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mode: \(mode.name)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(mode.bindings) { binding in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    KeyCap(combo: binding.combo)
                        .frame(width: 150, alignment: .leading)
                    Text(binding.command)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct KeyCap: View {
    let combo: KeyCombo

    var body: some View {
        HStack(spacing: 3) {
            ForEach(combo.modifiers, id: \.self) { cap($0.symbol) }
            cap(combo.keyDisplay)
        }
    }

    private func cap(_ text: String) -> some View {
        Text(text)
            .font(.system(.callout, design: .rounded).weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.1)))
    }
}
