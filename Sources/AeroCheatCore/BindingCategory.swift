import Foundation

/// A section of the cheatsheet, from what a binding does. Declaration order is the order of the sections.
public enum BindingCategory: String, CaseIterable, Equatable {
    case focus, move, workspace, layout, resize, fullscreen, other

    public var title: String {
        switch self {
        case .focus: return "Focus"
        case .move: return "Move"
        case .workspace: return "Workspaces"
        case .layout: return "Layout"
        case .resize: return "Resize"
        case .fullscreen: return "Fullscreen"
        case .other: return "Other"
        }
    }

    /// The category of a binding, from the first word of its first command. A trailing `mode main`, as in
    /// `['layout tiles', 'mode main']`, does not change it.
    public init(commands: [String]) {
        let verb = commands.first?.split(whereSeparator: \.isWhitespace).first.map { $0.lowercased() } ?? ""
        self = Self.byCommand[verb] ?? .other
    }

    private static let byCommand: [String: BindingCategory] = [
        "focus": .focus, "focus-monitor": .focus, "focus-back-and-forth": .focus,
        "move": .move, "swap": .move, "join-with": .move,
        "move-node-to-workspace": .move, "move-node-to-monitor": .move, "move-workspace-to-monitor": .move,
        "workspace": .workspace, "workspace-back-and-forth": .workspace, "summon-workspace": .workspace,
        "layout": .layout, "split": .layout, "flatten-workspace-tree": .layout, "balance-sizes": .layout,
        "resize": .resize,
        "fullscreen": .fullscreen, "macos-native-fullscreen": .fullscreen,
    ]
}

extension Binding {
    public var category: BindingCategory { BindingCategory(commands: commands) }
}

extension BindingMode {
    /// The bindings by category, in category order; each keeps the file order and empty categories are left out.
    public var sections: [(category: BindingCategory, bindings: [Binding])] {
        let grouped = Dictionary(grouping: bindings, by: \.category)
        return BindingCategory.allCases.compactMap { category in
            grouped[category].map { (category, $0) }
        }
    }
}
