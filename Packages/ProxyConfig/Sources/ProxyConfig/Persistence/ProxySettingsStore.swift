import Foundation

/// Persistencia de los ajustes no sensibles y del estado del asistente inicial.
public protocol ProxySettingsStore: AnyObject {
    func loadSettings() -> ProxySettings
    func saveSettings(_ settings: ProxySettings) throws
    var hasCompletedSetup: Bool { get set }
}

/// Guarda los ajustes como JSON en `UserDefaults`.
public final class UserDefaultsProxySettingsStore: ProxySettingsStore {
    private enum Key {
        static let settings = "proxySettings.v1"
        static let setupCompleted = "proxySettings.setupCompleted"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Si no hay datos o están dañados, devuelve los valores por defecto.
    public func loadSettings() -> ProxySettings {
        guard let data = defaults.data(forKey: Key.settings),
              let settings = try? decoder.decode(ProxySettings.self, from: data) else {
            return .default
        }
        return settings
    }

    public func saveSettings(_ settings: ProxySettings) throws {
        defaults.set(try encoder.encode(settings), forKey: Key.settings)
    }

    public var hasCompletedSetup: Bool {
        get { defaults.bool(forKey: Key.setupCompleted) }
        set { defaults.set(newValue, forKey: Key.setupCompleted) }
    }
}
