import XCTest
@testable import AeroCheatCore

final class ConfigPathTests: XCTestCase {
    private var dir: URL!
    private var home: String { dir.path }
    private var suiteName = ""
    private var suite: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Resolve /var -> /private/var once so expected paths match what the file system reports.
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("aerocheat-path-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        dir = base
        suiteName = "AeroCheatPathTests-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        // Restore permissions so cleanup can delete everything.
        if let items = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            for item in items { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: dir.appendingPathComponent(item).path) }
        }
        try? FileManager.default.removeItem(at: dir)
        suite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let validConfig = "[mode.main.binding]\nalt-h = 'focus left'\nalt-l = ['focus right', 'layout tiles']\n\n[mode.service.binding]\nesc = 'mode main'\n"

    @discardableResult
    private func write(_ name: String, _ text: String? = nil) throws -> String {
        let url = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (text ?? validConfig).write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    private func load(_ setting: ConfigPathSetting) -> ConfigLoadResult {
        AeroSpaceConfigLoader.load(setting, home: home)
    }

    private func failure(_ result: ConfigLoadResult, file: StaticString = #filePath, line: UInt = #line) -> (path: String, message: String)? {
        guard case .failed(let path, let message) = result else {
            XCTFail("expected a failure, got \(result)", file: file, line: line)
            return nil
        }
        return (path, message)
    }

    // MARK: Setting

    func testEmptyOrBlankTextMeansAutomatic() {
        XCTAssertEqual(ConfigPathSetting(text: ""), .automatic)
        XCTAssertEqual(ConfigPathSetting(text: " \t\n"), .automatic)
        XCTAssertEqual(ConfigPathSetting(text: "  ~/x.toml \n"), .custom("~/x.toml"))
        XCTAssertEqual(ConfigPathSetting.custom("a").text, "a")
        XCTAssertEqual(ConfigPathSetting.automatic.text, "")
    }

    // MARK: Resolution

    func testResolveExpandsTildeRelativePathsAndWhitespace() throws {
        XCTAssertEqual(try ConfigPath.resolve("~/cfg/a.toml", home: "/Users/x"), "/Users/x/cfg/a.toml")
        XCTAssertEqual(try ConfigPath.resolve("~", home: "/Users/x"), "/Users/x")
        XCTAssertEqual(try ConfigPath.resolve("cfg/a.toml", home: "/Users/x"), "/Users/x/cfg/a.toml")
        XCTAssertEqual(try ConfigPath.resolve("./cfg/../a.toml", home: "/Users/x"), "/Users/x/a.toml")
        XCTAssertEqual(try ConfigPath.resolve("  /etc/a.toml \n", home: "/Users/x"), "/etc/a.toml")
    }

    func testInvalidPathsAreErrors() {
        XCTAssertThrowsError(try ConfigPath.resolve("  ", home: "/h")) { XCTAssertEqual($0 as? ConfigPathError, .invalidPath("the path is empty")) }
        XCTAssertThrowsError(try ConfigPath.resolve("a\0b", home: "/h"))
        XCTAssertThrowsError(try ConfigPath.resolve("~bob/a.toml", home: "/h"))
        XCTAssertNotNil(failure(load(.custom("~bob/x.toml"))), "an unresolvable path is reported as a failure")
        XCTAssertNotNil(failure(load(.custom("a\0b"))))
    }

    // MARK: Loading

    func testAutomaticKeepsTheDefaultSearchOrder() throws {
        XCTAssertEqual(load(.automatic), .missing(searched: AeroSpaceConfigLoader.defaultPaths(home: home)))
        let second = try write(".config/aerospace/aerospace.toml")
        XCTAssertEqual(load(.automatic).effectivePath, second)
        let first = try write(".aerospace.toml")
        XCTAssertEqual(load(.automatic).effectivePath, first)
        XCTAssertEqual(load(.automatic), AeroSpaceConfigLoader.load(paths: AeroSpaceConfigLoader.defaultPaths(home: home)))
    }

    func testCustomAbsolutePathLoads() throws {
        let path = try write("elsewhere/my.toml")
        let result = load(.custom(path))
        XCTAssertEqual(result.effectivePath, path)
        XCTAssertEqual(result.bindingCount, 3)
        guard case .loaded(_, let modes) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(modes.map(\.name), ["main", "service"])
    }

    func testCustomPathIgnoresTheDefaultLocations() throws {
        try write(".aerospace.toml")
        let result = load(.custom("nope.toml"))
        XCTAssertEqual(failure(result)?.path, home + "/nope.toml")
        XCTAssertNil(result.bindingCount, "no silent fallback to ~/.aerospace.toml")
    }

    func testCustomPathThroughSymlinkLoads() throws {
        let target = try write("real/aerospace.toml")
        let link = dir.appendingPathComponent("link.toml")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target)
        let viaLink = load(.custom(link.path))
        XCTAssertEqual(viaLink.effectivePath, link.path)
        XCTAssertEqual(viaLink.bindingCount, 3)
        let dirLink = dir.appendingPathComponent("linkdir")
        try FileManager.default.createSymbolicLink(atPath: dirLink.path, withDestinationPath: dir.appendingPathComponent("real").path)
        XCTAssertEqual(load(.custom("~/linkdir/aerospace.toml")).bindingCount, 3)
    }

    func testMissingFileIsAnError() throws {
        let (path, message) = failure(load(.custom("~/gone.toml"))) ?? ("", "")
        XCTAssertEqual(path, home + "/gone.toml")
        XCTAssertEqual(message, ConfigPathError.notFound.description)
        let link = dir.appendingPathComponent("dangling.toml")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: dir.path + "/gone.toml")
        XCTAssertEqual(failure(load(.custom(link.path)))?.message, ConfigPathError.notFound.description, "a dangling symlink is a missing file")
    }

    func testDirectoryInsteadOfFileIsAnError() throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("folder.toml"), withIntermediateDirectories: true)
        XCTAssertEqual(failure(load(.custom("folder.toml")))?.message, ConfigPathError.isDirectory.description)
        XCTAssertEqual(failure(load(.custom("~")))?.message, ConfigPathError.isDirectory.description)
    }

    func testUnreadableFileIsAnError() throws {
        let path = try write("secret.toml")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: path)
        try XCTSkipIf(FileManager.default.isReadableFile(atPath: path), "running with privileges that read anything")
        let message = failure(load(.custom(path)))?.message ?? ""
        XCTAssertTrue(message.hasPrefix("Cannot read the file"), message)
    }

    func testParserErrorsAreReportedAsFailures() throws {
        let path = try write("bad.toml", "[mode.main.binding\nalt-h = 'x'\n")
        let (shown, message) = failure(load(.custom(path))) ?? ("", "")
        XCTAssertEqual(shown, path)
        XCTAssertTrue(message.hasPrefix("Syntax error at"), message)
        XCTAssertTrue(message.contains("line 1"), message)
        let binary = dir.appendingPathComponent("blob.toml")
        try Data([0xFF, 0xFE, 0x00, 0xD8]).write(to: binary)
        XCTAssertEqual(failure(load(.custom(binary.path)))?.message, ConfigPathError.notUTF8.description)
        let invalid = try write("num.toml", "[mode.main.binding]\nalt-h = 42\n")
        XCTAssertEqual(failure(load(.custom(invalid)))?.message, AeroSpaceConfigError.invalidBinding(mode: "main", key: "alt-h").description)
    }

    func testEmptyFileIsValidWithNoBindings() throws {
        let path = try write("empty.toml", "")
        XCTAssertEqual(load(.custom(path)).bindingCount, 0)
    }

    func testCorruptSettingIsAnErrorNotTheDefault() throws {
        try write(".aerospace.toml")
        let result = load(.corrupt)
        XCTAssertEqual(failure(result)?.message, ConfigPathError.corruptSetting.description)
        XCTAssertNil(result.bindingCount)
    }

    // MARK: Persistence

    func testNothingOrBlankStoredIsAutomatic() {
        XCTAssertEqual(ConfigPathStorage(defaults: suite).load(), .automatic)
        suite.set("   ", forKey: "config.path")
        XCTAssertEqual(ConfigPathStorage(defaults: suite).load(), .automatic, "a blank stored string is the default too")
    }

    func testRoundTrip() {
        let storage = ConfigPathStorage(defaults: suite)
        storage.save(.custom("~/cfg/a.toml"))
        XCTAssertEqual(storage.load(), .custom("~/cfg/a.toml"))
        XCTAssertEqual(suite.string(forKey: "config.path"), "~/cfg/a.toml")
        storage.save(.automatic)
        XCTAssertEqual(storage.load(), .automatic)
        XCTAssertNil(suite.object(forKey: "config.path"), "automatic stores nothing")
    }

    func testStoredValueOfTheWrongTypeIsCorrupt() {
        let storage = ConfigPathStorage(defaults: suite)
        suite.set(42, forKey: "config.path")
        XCTAssertEqual(storage.load(), .corrupt)
        suite.set(["a"], forKey: "config.path")
        XCTAssertEqual(storage.load(), .corrupt)
        storage.save(.corrupt)
        XCTAssertEqual(storage.load(), .corrupt, "saving a corrupt value does not repair it")
        storage.clear()
        XCTAssertEqual(storage.load(), .automatic)
    }
}
