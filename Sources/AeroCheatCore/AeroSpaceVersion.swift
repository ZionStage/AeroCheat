import Foundation

/// An AeroSpace version such as `0.21.3-Beta`.
public struct AeroSpaceVersion: Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// `aerospace subscribe` first shipped in 0.21.0-Beta.
    public static let minimumForSubscribe = AeroSpaceVersion(major: 0, minor: 21, patch: 0)

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: AeroSpaceVersion, rhs: AeroSpaceVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    /// Reads the first `X.Y[.Z]` number in `text`.
    public static func parse(_ text: String) -> AeroSpaceVersion? {
        guard let range = text.range(of: #"\d+\.\d+(\.\d+)?"#, options: .regularExpression) else { return nil }
        let parts = text[range].split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return AeroSpaceVersion(major: parts[0], minor: parts[1], patch: parts.count > 2 ? parts[2] : 0)
    }

    /// The oldest version reported by `aerospace --version`, which prints one line for the CLI and,
    /// when the server answers, one for the app. Taking the oldest is the safe reading.
    public static func parse(versionOutput: String) -> AeroSpaceVersion? {
        versionOutput.split(whereSeparator: \.isNewline)
            .compactMap { parse(String($0)) }
            .min()
    }
}

public enum AeroSpaceBinary {
    /// Where to look for `aerospace`: Homebrew locations first, then the entries of `PATH`.
    /// A Finder or login-item launch gets a minimal `PATH`, so absolute locations come first.
    public static func candidates(path: String?) -> [String] {
        var result = ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace"]
        for directory in (path ?? "").split(separator: ":") where !directory.isEmpty {
            let candidate = String(directory) + "/aerospace"
            if !result.contains(candidate) { result.append(candidate) }
        }
        return result
    }
}
