import SwiftUI

/// Temas de la documentación, en el orden en que se muestran.
enum DocumentationTopic: String, CaseIterable, Identifiable {
    case desktopApp
    case manualSetup
    case connectionModes
    case terminal
    case systemWide
    case renewal
    case privacy
    case troubleshooting

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .desktopApp:
            return "docs.desktop.title"
        case .manualSetup:
            return "docs.manual.title"
        case .connectionModes:
            return "docs.modes.title"
        case .terminal:
            return "docs.terminal.title"
        case .systemWide:
            return "docs.systemWide.title"
        case .renewal:
            return "docs.renewal.title"
        case .privacy:
            return "docs.privacy.title"
        case .troubleshooting:
            return "docs.troubleshooting.title"
        }
    }

    var summaryKey: LocalizedStringKey {
        switch self {
        case .desktopApp:
            return "docs.desktop.summary"
        case .manualSetup:
            return "docs.manual.summary"
        case .connectionModes:
            return "docs.modes.summary"
        case .terminal:
            return "docs.terminal.summary"
        case .systemWide:
            return "docs.systemWide.summary"
        case .renewal:
            return "docs.renewal.summary"
        case .privacy:
            return "docs.privacy.summary"
        case .troubleshooting:
            return "docs.troubleshooting.summary"
        }
    }

    var systemImage: String {
        switch self {
        case .desktopApp:
            return "laptopcomputer"
        case .manualSetup:
            return "slider.horizontal.3"
        case .connectionModes:
            return "cable.connector"
        case .terminal:
            return "terminal"
        case .systemWide:
            return "network"
        case .renewal:
            return "calendar.badge.clock"
        case .privacy:
            return "lock.shield"
        case .troubleshooting:
            return "wrench.and.screwdriver"
        }
    }
}
