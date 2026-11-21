import ProxyConfig
import SwiftUI

/// Bloque de un artículo de la documentación.
enum DocumentationBlock {
    case heading(LocalizedStringKey)
    case paragraph(LocalizedStringKey)
    case bullet(LocalizedStringKey)
    /// Comando o valor que se copia tal cual; no se traduce.
    case command(String)
}

/// Contenido de cada artículo. Los comandos usan los datos de conexión actuales de la app.
enum DocumentationContent {
    static func blocks(for topic: DocumentationTopic, details: ClientConnectionDetails) -> [DocumentationBlock] {
        switch topic {
        case .desktopApp:
            return desktopApp
        case .manualSetup:
            return []
        case .connectionModes:
            return connectionModes
        case .terminal:
            return terminal(details: details)
        case .systemWide:
            return systemWide
        case .renewal:
            return renewal
        case .privacy:
            return privacy
        case .troubleshooting:
            return troubleshooting
        }
    }

    private static let desktopApp: [DocumentationBlock] = [
        .paragraph("docs.desktop.intro"),
        .heading("docs.desktop.download.title"),
        .paragraph("docs.desktop.download"),
        .heading("docs.desktop.use.title"),
        .bullet("docs.desktop.use.1"),
        .bullet("docs.desktop.use.2"),
        .bullet("docs.desktop.use.3"),
        .bullet("docs.desktop.use.4"),
        .heading("docs.desktop.requirements.title"),
        .bullet("docs.desktop.requirements.windows"),
        .bullet("docs.desktop.requirements.macos"),
        .bullet("docs.desktop.requirements.linux"),
    ]

    private static let connectionModes: [DocumentationBlock] = [
        .heading("transport.usb"),
        .paragraph("docs.modes.usb"),
        .heading("transport.wifi"),
        .paragraph("docs.modes.wifi"),
        .bullet("docs.modes.wifi.clients"),
        .bullet("docs.modes.wifi.localNetwork"),
        .bullet("docs.modes.wifi.trusted"),
    ]

    private static func terminal(details: ClientConnectionDetails) -> [DocumentationBlock] {
        let http = "http://\(details.proxyAddress)"
        let socks = "socks5h://\(details.proxyAddress)"
        return [
            .paragraph("docs.terminal.intro"),
            .heading("docs.terminal.posix"),
            .command("export http_proxy=\(http) https_proxy=\(http) ALL_PROXY=\(socks)"),
            .heading("docs.terminal.windows"),
            .command("$env:HTTP_PROXY=\"\(http)\"; $env:HTTPS_PROXY=\"\(http)\"; $env:ALL_PROXY=\"\(socks)\""),
            .heading("docs.terminal.verify"),
            .command(ClientSetupGuide.verifyCommand(for: details)),
            .paragraph("docs.terminal.socks"),
        ]
    }

    private static let systemWide: [DocumentationBlock] = [
        .paragraph("docs.systemWide.intro"),
        .bullet("docs.systemWide.when"),
        .paragraph("docs.systemWide.guide"),
    ]

    private static let renewal: [DocumentationBlock] = [
        .paragraph("docs.renewal.intro"),
        .bullet("docs.renewal.step.1"),
        .bullet("docs.renewal.step.2"),
        .bullet("docs.renewal.step.3"),
        .paragraph("docs.renewal.reminder"),
        .heading("docs.renewal.auto.title"),
        .paragraph("docs.renewal.auto.intro"),
        .bullet("docs.renewal.auto.step.1"),
        .bullet("docs.renewal.auto.step.2"),
        .bullet("docs.renewal.auto.step.3"),
        .paragraph("docs.renewal.auto.fallback"),
    ]

    private static let privacy: [DocumentationBlock] = [
        .bullet("docs.privacy.usb"),
        .bullet("docs.privacy.wifi"),
        .bullet("docs.privacy.password"),
        .bullet("docs.privacy.noTracking"),
        .bullet("docs.privacy.unencrypted"),
        .paragraph("docs.privacy.carrier"),
    ]

    private static let troubleshooting: [DocumentationBlock] = [
        .heading("docs.trouble.noDevice.title"),
        .paragraph("docs.trouble.noDevice"),
        .heading("docs.trouble.noInternet.title"),
        .paragraph("docs.trouble.noInternet"),
        .heading("docs.trouble.portInUse.title"),
        .paragraph("docs.trouble.portInUse"),
        .heading("docs.trouble.ignoresProxy.title"),
        .paragraph("docs.trouble.ignoresProxy"),
        .heading("docs.trouble.screenLock.title"),
        .paragraph("docs.trouble.screenLock"),
        .heading("docs.trouble.udp.title"),
        .paragraph("docs.trouble.udp"),
    ]
}
