import Foundation

/// The application that owns a window, as the system names it. Either part can be unknown.
public struct AppIdentity: Equatable {
    /// The localised name shown in the menu bar, such as "Finder".
    public let name: String?
    public let bundleID: String?

    public init(name: String?, bundleID: String?) {
        self.name = name
        self.bundleID = bundleID
    }
}

extension DisplaySettings {
    /// Whether focus landing on a window of `app` must stay silent: an entry of `ignoredApps` equals its name or
    /// its bundle identifier, ignoring case. An unknown app is never ignored.
    public func ignores(_ app: AppIdentity?) -> Bool {
        guard let app else { return false }
        let names = [app.name, app.bundleID].compactMap { $0?.lowercased() }
        return ignoredApps.contains { names.contains($0.lowercased()) }
    }

    /// The entries of a list typed by hand, separated by commas or new lines: trimmed, without blanks or repeats.
    public static func appList(_ text: String) -> [String] {
        appList(text.components(separatedBy: CharacterSet(charactersIn: ",\n")))
    }

    static func appList(_ entries: [String]) -> [String] {
        var seen: Set<String> = []
        return entries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
