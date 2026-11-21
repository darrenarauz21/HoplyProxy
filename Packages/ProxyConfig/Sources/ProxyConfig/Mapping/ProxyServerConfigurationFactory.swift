import Foundation
import ProxyCore

/// Convierte los ajustes del usuario en la configuración que entiende el servidor.
public enum ProxyServerConfigurationFactory {
    public static func make(from settings: ProxySettings, password: String?) throws -> ProxyServerConfiguration {
        let issues = ProxySettingsValidator.validate(settings, password: password)
        guard issues.isEmpty else { throw ProxySettingsValidationError(issues: issues) }

        let credentials: ProxyCredentials? = settings.authenticationEnabled
            ? password.map { ProxyCredentials(username: settings.username, password: $0) }
            : nil

        let allowedClients = settings.transport == .wifi
            ? settings.allowedClients.compactMap { IPv4Subnet($0) }
            : []

        return ProxyServerConfiguration(
            port: settings.port,
            maximumConnections: settings.maximumConnections,
            idleTimeout: TimeInterval(settings.idleTimeoutSeconds),
            connectTimeout: ProxyServerConfiguration.default.connectTimeout,
            listenScope: settings.transport == .wifi ? .wifi : .loopback,
            credentials: credentials,
            allowedClients: allowedClients
        )
    }
}
