import Foundation

/// How many times each shortcut was pressed, as AeroSpace reports it (`binding-triggered`, so only while
/// active mode listens). Kept on this Mac only: no network, no telemetry.
public struct ShortcutUsage: Equatable {
    /// Presses by `"<mode>/<canonical combo>"`, so `alt-ctrl-3` and `ctrl-alt-3` count together.
    public private(set) var counts: [String: Int]

    /// Below this many presses in a mode, nothing is marked as rarely used: there is not enough to compare.
    public static let minimumPresses = 20

    public init(counts: [String: Int] = [:]) {
        self.counts = counts.filter { $0.value > 0 }
    }

    public mutating func record(binding raw: String, mode: String) {
        counts[Self.key(raw, mode), default: 0] += 1
    }

    public func count(of combo: KeyCombo, mode: String) -> Int {
        counts[Self.key(combo.raw, mode)] ?? 0
    }

    /// Ids of the bindings of `mode` used the least: the quarter with the lowest counts (ties included), as long
    /// as some binding was used more. Empty until the mode has `minimumPresses` presses.
    public func rarelyUsed(in mode: BindingMode) -> Set<String> {
        let counted = mode.bindings.map { ($0.id, count(of: $0.combo, mode: mode.name)) }
        let sorted = counted.map(\.1).sorted()
        guard let top = sorted.last, sorted.reduce(0, +) >= Self.minimumPresses else { return [] }
        let threshold = sorted[(sorted.count - 1) / 4]
        return Set(counted.filter { $0.1 <= threshold && $0.1 < top }.map(\.0))
    }

    private static func key(_ raw: String, _ mode: String) -> String {
        mode + "/" + KeyCombo(raw: raw).canonical
    }
}

/// Reads and writes `ShortcutUsage` as one `UserDefaults` dictionary, next to the display settings. A damaged
/// entry reads as no usage. The defaults object is injected: tests use a throwaway suite.
public struct ShortcutUsageStorage {
    static let key = "usage.presses"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ShortcutUsage {
        ShortcutUsage(counts: defaults.object(forKey: Self.key) as? [String: Int] ?? [:])
    }

    public func save(_ usage: ShortcutUsage) {
        defaults.set(usage.counts, forKey: Self.key)
    }
}
