import Foundation

public enum BindingFilter {
    /// Keeps the bindings matching every word of `query` (case-insensitive) in the combo
    /// (as written, as symbols, or with modifiers spelled out), in the command or in its category title.
    /// Modes left without bindings are dropped when a query is active.
    public static func apply(_ query: String, to modes: [BindingMode]) -> [BindingMode] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return modes }
        return modes.compactMap { mode in
            let matches = mode.bindings.filter { binding in
                let haystack = [
                    binding.combo.raw, binding.combo.display, binding.combo.modifierWords,
                    binding.command, binding.category.title, mode.name,
                ].joined(separator: " ").lowercased()
                return words.allSatisfy { haystack.contains($0) }
            }
            return matches.isEmpty ? nil : BindingMode(name: mode.name, bindings: matches)
        }
    }
}
