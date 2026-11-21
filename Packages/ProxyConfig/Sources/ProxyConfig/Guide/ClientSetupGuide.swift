import ProxyCore

/// Sistema operativo de la laptop.
public enum ClientPlatform: String, CaseIterable, Codable, Sendable {
    case windows
    case macOS
    case linux
}

/// Datos que la laptop necesita para usar el proxy.
public struct ClientConnectionDetails: Equatable, Sendable {
    public let transport: TransportMode
    public let proxyHost: String
    public let port: UInt16
    /// `nil` cuando el proxy no exige autenticación.
    public let username: String?

    public init(transport: TransportMode, proxyHost: String, port: UInt16, username: String?) {
        self.transport = transport
        self.proxyHost = proxyHost
        self.port = port
        self.username = username
    }

    /// Dirección del proxy en `host:puerto`; sirve tanto para HTTP como para SOCKS5.
    public var proxyAddress: String {
        "\(proxyHost):\(port)"
    }

    public var pacURL: String {
        PacScriptGenerator.url(proxyHost: proxyHost, port: port)
    }
}

/// Paso de configuración de la laptop. La capa de presentación decide el texto de cada caso.
public enum ClientSetupStep: Equatable, Sendable {
    case connectCable
    case installAppleDevices
    case installUsbmuxd(command: String)
    case installGoIos(command: String)
    case runForward(command: String)
    case joinSameWiFi
    case configureSystemPac(platform: ClientPlatform, url: String)
    case configureFirefox(proxyAddress: String)
    /// El navegador o el sistema pedirán estas credenciales al usar el proxy HTTP.
    case enterCredentials(username: String)
    case verify(command: String)
    /// Aviso opcional: las apps que ignoran el proxy necesitan un túnel de sistema (tun2socks).
    case systemWideTunnel
}

/// Construye la lista de pasos para un sistema operativo y un modo de conexión.
public enum ClientSetupGuide {
    public static let goIosInstallCommand = "npm install -g go-ios"
    public static let usbmuxdInstallCommand = "sudo apt install usbmuxd"
    public static let verificationURL = "https://ifconfig.me"

    public static func steps(for platform: ClientPlatform, details: ClientConnectionDetails) -> [ClientSetupStep] {
        var steps: [ClientSetupStep] = []

        switch details.transport {
        case .usb:
            steps.append(.connectCable)
            switch platform {
            case .windows:
                steps.append(.installAppleDevices)
            case .linux:
                steps.append(.installUsbmuxd(command: usbmuxdInstallCommand))
            case .macOS:
                break
            }
            steps.append(.installGoIos(command: goIosInstallCommand))
            steps.append(.runForward(command: forwardCommand(port: details.port)))
        case .wifi:
            steps.append(.joinSameWiFi)
        }

        steps.append(.configureSystemPac(platform: platform, url: details.pacURL))
        steps.append(.configureFirefox(proxyAddress: details.proxyAddress))
        if let username = details.username {
            steps.append(.enterCredentials(username: username))
        }
        steps.append(.verify(command: verifyCommand(for: details)))
        steps.append(.systemWideTunnel)
        return steps
    }

    /// Reenvía el puerto local de la laptop al mismo puerto del iPhone por USB.
    public static func forwardCommand(port: UInt16) -> String {
        "ios forward \(port) \(port)"
    }

    /// Usa el proxy HTTP. Con usuario configurado, curl solicita la contraseña de forma interactiva.
    public static func verifyCommand(for details: ClientConnectionDetails) -> String {
        let userOption = details.username.map { " --proxy-user \($0)" } ?? ""
        return "curl --proxy http://\(details.proxyAddress)\(userOption) \(verificationURL)"
    }
}
