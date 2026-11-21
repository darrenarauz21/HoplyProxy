/// Problema concreto de un ajuste, para indicar al usuario qué corregir.
public enum ProxySettingsIssue: Equatable, Hashable, Sendable {
    case portOutOfRange
    case usernameInvalid
    case passwordInvalid
    case allowedClientsRequired
    case allowedClientInvalid(String)
    case allowedClientTooBroad(String)
    case tooManyAllowedClients
    case maximumConnectionsOutOfRange
    case idleTimeoutOutOfRange
}

/// Error lanzado cuando los ajustes no pueden convertirse en una configuración válida.
public struct ProxySettingsValidationError: Error, Equatable {
    public let issues: [ProxySettingsIssue]

    public init(issues: [ProxySettingsIssue]) {
        self.issues = issues
    }
}
