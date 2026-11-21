/// Respuestas del proxy HTTP.
enum HttpProxyResponse {
    static let realm = "Hoply"

    /// Respuesta de éxito a `CONNECT`. No lleva `Content-Length` porque a continuación
    /// la conexión transporta los bytes del túnel.
    static func connectionEstablished() -> [UInt8] {
        Array("HTTP/1.1 200 Connection Established\r\n\r\n".utf8)
    }

    static func authenticationRequired() -> [UInt8] {
        HttpResponse.make(
            status: "407 Proxy Authentication Required",
            extraHeaders: ["Proxy-Authenticate: Basic realm=\"\(realm)\", charset=\"UTF-8\""]
        )
    }

    static func failure(for error: OutboundConnectionError) -> [UInt8] {
        switch error {
        case .invalidDestination:
            return HttpResponse.badRequest()
        case .timedOut:
            return HttpResponse.make(status: "504 Gateway Timeout")
        case .networkUnreachable, .hostUnreachable, .connectionRefused, .failed:
            return HttpResponse.make(status: "502 Bad Gateway")
        }
    }
}
