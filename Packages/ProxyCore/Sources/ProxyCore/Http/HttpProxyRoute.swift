import Socks5

/// Qué hacer con una solicitud HTTP recibida en el puerto del proxy.
enum HttpProxyRoute: Equatable {
    /// Recurso propio del servidor, como el archivo PAC.
    case localResource
    /// `CONNECT host:puerto`: túnel TCP, usado para HTTPS.
    case tunnel(Socks5Destination)
    /// Solicitud con URL absoluta `http://`: se reenvía al destino con la ruta reescrita.
    case forward(destination: Socks5Destination, authority: String, originTarget: String)

    static let defaultHttpPort: UInt16 = 80
    private static let httpScheme = "http://"

    static func resolve(_ head: HttpRequestHead) throws -> HttpProxyRoute {
        if head.method == "CONNECT" {
            guard let destination = HttpAuthority.destination(from: head.target, defaultPort: nil) else {
                throw HttpRequestError.malformed
            }
            return .tunnel(destination)
        }

        if head.target.hasPrefix("/") {
            return .localResource
        }

        guard head.target.lowercased().hasPrefix(httpScheme) else { throw HttpRequestError.malformed }
        let afterScheme = head.target.dropFirst(httpScheme.count)
        let authorityEnd = afterScheme.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? afterScheme.endIndex
        let authority = String(afterScheme[..<authorityEnd])

        // Las credenciales dentro de la URL no se admiten: suelen indicar un intento de engaño.
        guard !authority.contains("@"),
              let destination = HttpAuthority.destination(from: authority, defaultPort: defaultHttpPort) else {
            throw HttpRequestError.malformed
        }

        var originTarget = String(afterScheme[authorityEnd...])
        if let fragmentStart = originTarget.firstIndex(of: "#") {
            originTarget = String(originTarget[..<fragmentStart])
        }
        if originTarget.isEmpty {
            originTarget = "/"
        } else if originTarget.hasPrefix("?") {
            originTarget = "/" + originTarget
        }
        return .forward(destination: destination, authority: authority, originTarget: originTarget)
    }
}
