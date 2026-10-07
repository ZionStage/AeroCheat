import Foundation

/// Where the AeroSpace config comes from: the automatic search, or a path the user chose.
public enum ConfigPathSetting: Equatable {
    /// Today's behaviour: `~/.aerospace.toml`, then `~/.config/aerospace/aerospace.toml`.
    case automatic
    /// A path as the user wrote it (trimmed, never empty). `~` and relative paths are resolved when loading.
    case custom(String)
    /// The stored value is not a string: reported as an error, never replaced by the default.
    case corrupt

    /// Text from the settings field: surrounding whitespace is dropped, nothing left means automatic.
    public init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self = trimmed.isEmpty ? .automatic : .custom(trimmed)
    }

    /// What the settings text field shows.
    public var text: String {
        if case .custom(let path) = self { return path }
        return ""
    }
}

/// Reads and writes `ConfigPathSetting` as one `UserDefaults` entry (`config.path`). Absent means automatic,
/// a value that is not a string is `.corrupt`. The defaults object is injected: tests use a throwaway suite.
public struct ConfigPathStorage {
    static let key = "config.path"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ConfigPathSetting {
        guard let stored = defaults.object(forKey: Self.key) else { return .automatic }
        guard let text = stored as? String else { return .corrupt }
        return ConfigPathSetting(text: text)
    }

    public func save(_ setting: ConfigPathSetting) {
        switch setting {
        case .custom(let path): defaults.set(path, forKey: Self.key)
        case .automatic: defaults.removeObject(forKey: Self.key)
        case .corrupt: break
        }
    }

    public func clear() { defaults.removeObject(forKey: Self.key) }
}

public enum ConfigPathError: Error, Equatable, CustomStringConvertible {
    case corruptSetting
    case invalidPath(String)
    case notFound
    case isDirectory
    case unreadable(String)
    case notUTF8

    public var description: String {
        switch self {
        case .corruptSetting:
            return "The saved config path is damaged. Choose a file or use the default location."
        case .invalidPath(let reason):
            return "Invalid path: \(reason)"
        case .notFound:
            return "No file exists at this path (a symlink pointing nowhere counts as missing)."
        case .isDirectory:
            return "This path is a folder, not a file."
        case .unreadable(let reason):
            return "Cannot read the file: \(reason)"
        case .notUTF8:
            return "The file is not valid UTF-8 text"
        }
    }
}

public enum ConfigPath {
    /// The absolute path a custom value stands for: `~` and `~/…` expand to `home`, a relative path is taken
    /// from `home`, `.` and `..` are folded. Symlinks are left alone: the file system follows them on read.
    public static func resolve(_ text: String, home: String = NSHomeDirectory()) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ConfigPathError.invalidPath("the path is empty") }
        guard !trimmed.contains("\0") else { throw ConfigPathError.invalidPath("it contains a null character") }
        var path = trimmed
        if path == "~" {
            path = home
        } else if path.hasPrefix("~/") {
            path = home + "/" + path.dropFirst(2)
        } else if path.hasPrefix("~") {
            throw ConfigPathError.invalidPath("only ~ and ~/… are supported, not another user's home")
        } else if !path.hasPrefix("/") {
            path = home + "/" + path
        }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    /// Checks that `path` is a readable regular file (through symlinks), without reading it.
    static func validate(_ path: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { throw ConfigPathError.notFound }
        guard !isDirectory.boolValue else { throw ConfigPathError.isDirectory }
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw ConfigPathError.unreadable("permission denied")
        }
    }
}

extension ConfigLoadResult {
    /// The file in use, or that failed; `nil` when the automatic search found nothing.
    public var effectivePath: String? {
        switch self {
        case .loaded(let path, _), .failed(let path, _): return path
        case .missing: return nil
        }
    }

    /// Bindings found in the loaded config, over every mode.
    public var bindingCount: Int? {
        guard case .loaded(_, let modes) = self else { return nil }
        return modes.reduce(0) { $0 + $1.bindings.count }
    }
}
