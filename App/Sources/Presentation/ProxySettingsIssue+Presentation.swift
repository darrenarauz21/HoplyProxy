import ProxyConfig
import SwiftUI

extension ProxySettingsIssue {
    var messageKey: LocalizedStringKey {
        switch self {
        case .portOutOfRange:
            return "issue.port"
        case .usernameInvalid:
            return "issue.username"
        case .passwordInvalid:
            return "issue.password"
        case .allowedClientsRequired:
            return "issue.clients.required"
        case .allowedClientInvalid(let entry):
            return "issue.clients.invalid \(entry)"
        case .allowedClientTooBroad(let entry):
            return "issue.clients.tooBroad \(entry)"
        case .tooManyAllowedClients:
            return "issue.clients.tooMany \(ProxySettingsValidator.maximumAllowedClients)"
        case .maximumConnectionsOutOfRange:
            return "issue.maximumConnections"
        case .idleTimeoutOutOfRange:
            return "issue.idleTimeout"
        }
    }
}
