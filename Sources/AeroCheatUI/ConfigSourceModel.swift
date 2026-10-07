import AeroCheatCore
import Combine
import Foundation

/// The live AeroSpace config: which path is used (`setting`) and what loading it gave (`result`). Changing the
/// path saves it, reloads at once and tells the observers (cheatsheet panel, active mode), as does `reload()`.
/// The file is only ever read. Main thread only.
public final class ConfigSourceModel: ObservableObject {
    @Published public private(set) var setting: ConfigPathSetting
    @Published public private(set) var result: ConfigLoadResult

    private let storage: ConfigPathStorage?
    private let loader: (ConfigPathSetting) -> ConfigLoadResult
    private var observers: [(ConfigLoadResult) -> Void] = []

    /// Starts from what `storage` holds and loads it. `loader` is injectable so tests never touch `$HOME`.
    public init(
        storage: ConfigPathStorage? = ConfigPathStorage(),
        home: String = NSHomeDirectory(),
        loader: ((ConfigPathSetting) -> ConfigLoadResult)? = nil
    ) {
        self.storage = storage
        let load = loader ?? { AeroSpaceConfigLoader.load($0, home: home) }
        let setting = storage?.load() ?? .automatic
        self.loader = load
        self.setting = setting
        result = load(setting)
    }

    /// `observer` is called after each load that `setPath`, `useDefaultLocation` or `reload` performs.
    public func addObserver(_ observer: @escaping (ConfigLoadResult) -> Void) {
        observers.append(observer)
    }

    /// Empty (after trimming) means the automatic search.
    public func setPath(_ text: String) {
        apply(ConfigPathSetting(text: text))
    }

    public func useDefaultLocation() { apply(.automatic) }

    public func reload() { apply(setting) }

    private func apply(_ new: ConfigPathSetting) {
        if new != setting {
            setting = new
            if new == .automatic { storage?.clear() } else { storage?.save(new) }
        }
        result = loader(new)
        observers.forEach { $0(result) }
    }
}
