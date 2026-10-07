import AeroCheatCore
import AeroCheatUI
import XCTest

final class ConfigSourceModelTests: XCTestCase {
    private var suiteName = ""
    private var suite: UserDefaults!
    private var dir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "AeroCheatConfigModelTests-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("aerocheat-model-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        suite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func model() -> ConfigSourceModel {
        ConfigSourceModel(storage: ConfigPathStorage(defaults: suite), home: dir.path)
    }

    private func write(_ name: String, _ bindings: Int) throws -> String {
        let text = "[mode.main.binding]\n" + (0..<bindings).map { "alt-\($0) = 'workspace \($0)'\n" }.joined()
        let url = dir.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    func testChangingThePathReloadsSavesAndNotifies() throws {
        let path = try write("custom.toml", 2)
        let model = model()
        var heard: [ConfigLoadResult] = []
        model.addObserver { heard.append($0) }
        model.setPath("  ~/custom.toml ")
        XCTAssertEqual(model.setting, .custom("~/custom.toml"))
        XCTAssertEqual(model.result.effectivePath, path)
        XCTAssertEqual(model.result.bindingCount, 2)
        XCTAssertEqual(heard, [model.result])
        XCTAssertEqual(suite.string(forKey: "config.path"), "~/custom.toml")
        XCTAssertEqual(self.model().result.effectivePath, path, "a new launch reads the saved path")
    }

    func testReloadPicksUpAnEditedFile() throws {
        _ = try write("custom.toml", 1)
        let model = model()
        model.setPath("custom.toml")
        XCTAssertEqual(model.result.bindingCount, 1)
        var heard = 0
        model.addObserver { _ in heard += 1 }
        _ = try write("custom.toml", 4)
        model.reload()
        XCTAssertEqual(model.result.bindingCount, 4)
        XCTAssertEqual(heard, 1)
    }

    func testUseDefaultLocationForgetsTheCustomPath() throws {
        _ = try write(".aerospace.toml", 1)
        _ = try write("custom.toml", 3)
        let model = model()
        model.setPath("custom.toml")
        XCTAssertEqual(model.result.bindingCount, 3)
        model.useDefaultLocation()
        XCTAssertEqual(model.setting, .automatic)
        XCTAssertEqual(model.result.bindingCount, 1)
        XCTAssertNil(suite.object(forKey: "config.path"))
        model.setPath("custom.toml")
        model.setPath("   ")
        XCTAssertEqual(model.setting, .automatic, "an empty field means the default")
    }

    func testABadPathShowsTheErrorAndKeepsItSaved() {
        let model = model()
        model.setPath("missing.toml")
        guard case .failed(let path, _) = model.result else { return XCTFail("\(model.result)") }
        XCTAssertEqual(path, dir.path + "/missing.toml")
        XCTAssertEqual(suite.string(forKey: "config.path"), "missing.toml")
    }

    func testCorruptStoredValueIsReportedAtStart() {
        suite.set(7, forKey: "config.path")
        let model = model()
        XCTAssertEqual(model.setting, .corrupt)
        guard case .failed = model.result else { return XCTFail("\(model.result)") }
        model.setPath("x.toml")
        XCTAssertEqual(model.setting, .custom("x.toml"))
    }

    func testInMemoryModelNeverWritesDefaults() throws {
        _ = try write("custom.toml", 1)
        let model = ConfigSourceModel(storage: nil, home: dir.path)
        model.setPath("custom.toml")
        XCTAssertEqual(model.result.bindingCount, 1)
        XCTAssertNil(suite.object(forKey: "config.path"))
    }
}
