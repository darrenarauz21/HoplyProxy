import Foundation
import ProxyCore

/// Reglas de validación de los ajustes del usuario.
public enum ProxySettingsValidator {
    public static let usernameLengthRange = 3...32
    public static let passwordLengthRange = 12...64
    public static let maximumAllowedClients = 16
    /// Rangos más amplios que /8 equivalen a abrir el proxy a casi cualquier dirección.
    public static let minimumAllowedPrefixLength: UInt8 = 8

    public static func validate(_ settings: ProxySettings, password: String?) -> [ProxySettingsIssue] {
        var issues: [ProxySettingsIssue] = []

        if !ProxyServerConfiguration.portRange.contains(settings.port) {
            issues.append(.portOutOfRange)
        }
        if !ProxyServerConfiguration.maximumConnectionsRange.contains(settings.maximumConnections) {
            issues.append(.maximumConnectionsOutOfRange)
        }
        if !ProxyServerConfiguration.idleTimeoutRange.contains(TimeInterval(settings.idleTimeoutSeconds)) {
            issues.append(.idleTimeoutOutOfRange)
        }
        if settings.authenticationEnabled {
            if !isValidUsername(settings.username) {
                issues.append(.usernameInvalid)
            }
            if !isValidPassword(password) {
                issues.append(.passwordInvalid)
            }
        }
        if settings.transport == .wifi {
            issues.append(contentsOf: allowedClientIssues(settings.allowedClients))
        }
        return issues
    }

    /// Letras, dígitos, punto, guion y guion bajo.
    public static func isValidUsername(_ username: String) -> Bool {
        usernameLengthRange.contains(username.count) && username.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || "._-".unicodeScalars.contains(scalar))
        }
    }

    /// ASCII imprimible sin espacios.
    public static func isValidPassword(_ password: String?) -> Bool {
        guard let password else { return false }
        return passwordLengthRange.contains(password.count)
            && password.unicodeScalars.allSatisfy { (0x21...0x7E).contains($0.value) }
    }

    private static func allowedClientIssues(_ entries: [String]) -> [ProxySettingsIssue] {
        guard !entries.isEmpty else { return [.allowedClientsRequired] }

        var issues: [ProxySettingsIssue] = []
        if entries.count > maximumAllowedClients {
            issues.append(.tooManyAllowedClients)
        }
        for entry in entries {
            guard let subnet = IPv4Subnet(entry) else {
                issues.append(.allowedClientInvalid(entry))
                continue
            }
            if subnet.prefixLength < minimumAllowedPrefixLength {
                issues.append(.allowedClientTooBroad(entry))
            }
        }
        return issues
    }
}
