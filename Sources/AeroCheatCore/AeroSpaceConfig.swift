import Foundation

public struct Binding: Equatable, Identifiable {
    public let combo: KeyCombo
    /// Commands run by the binding, in order (AeroSpace accepts a string or an array of strings).
    public let commands: [String]

    public var id: String { combo.raw }
    /// Commands joined for display, e.g. `layout tiles; focus left`.
    public var command: String { commands.joined(separator: "; ") }
}

/// The bindings of one `[mode.<name>.binding]` table.
public struct BindingMode: Equatable, Identifiable {
    public let name: String
    public let bindings: [Binding]

    public var id: String { name }
}

public enum AeroSpaceConfigError: Error, Equatable, CustomStringConvertible {
    case syntax(TOMLError)
    case invalidBinding(mode: String, key: String)

    public var description: String {
        switch self {
        case .syntax(let error):
            return "Syntax error at \(error)"
        case .invalidBinding(let mode, let key):
            return "Binding '\(key)' in mode '\(mode)' must be a string or an array of strings"
        }
    }
}

public enum AeroSpaceConfig {
    /// Parses `[mode.<name>.binding]` tables, keeping modes and bindings in file order.
    public static func parse(_ text: String) throws -> [BindingMode] {
        let entries: [TOMLEntry]
        do {
            entries = try MiniTOML.parse(text)
        } catch let error as TOMLError {
            throw AeroSpaceConfigError.syntax(error)
        }

        var order: [String] = []
        var bindingsByMode: [String: [Binding]] = [:]
        for entry in entries {
            guard entry.path.count >= 4, entry.path[0] == "mode", entry.path[2] == "binding" else { continue }
            let mode = entry.path[1]
            let key = entry.path[3...].joined(separator: ".")
            guard let commands = commands(from: entry.value) else {
                throw AeroSpaceConfigError.invalidBinding(mode: mode, key: key)
            }
            if bindingsByMode[mode] == nil { order.append(mode) }
            bindingsByMode[mode, default: []].append(Binding(combo: KeyCombo(raw: key), commands: commands))
        }
        return order.map { BindingMode(name: $0, bindings: bindingsByMode[$0] ?? []) }
    }

    private static func commands(from value: TOMLValue) -> [String]? {
        switch value {
        case .string(let command):
            return [command]
        case .array(let items):
            var result: [String] = []
            for item in items {
                guard case .string(let command) = item else { return nil }
                result.append(command)
            }
            return result
        case .other:
            return nil
        }
    }
}

/// What the panel has to show for the user's config.
public enum ConfigLoadResult: Equatable {
    case loaded(path: String, modes: [BindingMode])
    case missing(searched: [String])
    case failed(path: String, message: String)
}

public enum AeroSpaceConfigLoader {
    /// Locations AeroSpace reads, in priority order.
    public static func defaultPaths(home: String = NSHomeDirectory()) -> [String] {
        [
            home + "/.aerospace.toml",
            home + "/.config/aerospace/aerospace.toml",
        ]
    }

    /// Reads (never writes) the first existing config. Symlinks are followed by the file system.
    public static func load(paths: [String] = defaultPaths()) -> ConfigLoadResult {
        let fileManager = FileManager.default
        guard let path = paths.first(where: { fileManager.fileExists(atPath: $0) }) else {
            return .missing(searched: paths)
        }
        return read(path)
    }

    /// Loads what `setting` points at. A custom path is never mixed with the automatic search: when it cannot
    /// be used the result says why (`.failed` with that path), it does not fall back to the default location.
    public static func load(_ setting: ConfigPathSetting, home: String = NSHomeDirectory()) -> ConfigLoadResult {
        switch setting {
        case .automatic:
            return load(paths: defaultPaths(home: home))
        case .corrupt:
            return .failed(path: "", message: ConfigPathError.corruptSetting.description)
        case .custom(let text):
            let path: String
            do {
                path = try ConfigPath.resolve(text, home: home)
                try ConfigPath.validate(path)
            } catch {
                let shown = (try? ConfigPath.resolve(text, home: home)) ?? text
                return .failed(path: shown, message: (error as? ConfigPathError)?.description ?? "\(error)")
            }
            return read(path)
        }
    }

    private static func read(_ path: String) -> ConfigLoadResult {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            return .failed(path: path, message: ConfigPathError.unreadable(error.localizedDescription).description)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            return .failed(path: path, message: ConfigPathError.notUTF8.description)
        }
        do {
            return .loaded(path: path, modes: try AeroSpaceConfig.parse(text))
        } catch {
            return .failed(path: path, message: (error as? AeroSpaceConfigError)?.description ?? "\(error)")
        }
    }
}
