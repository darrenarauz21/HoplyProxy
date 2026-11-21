import ProxyConfig

extension ClientPlatform {
    /// Clave de `AppStorage` compartida por la guía y el asistente.
    static let storageKey = "guide.clientPlatform"

    /// Nombres propios: no se traducen.
    var displayName: String {
        switch self {
        case .windows:
            return "Windows"
        case .macOS:
            return "macOS"
        case .linux:
            return "Linux"
        }
    }
}
