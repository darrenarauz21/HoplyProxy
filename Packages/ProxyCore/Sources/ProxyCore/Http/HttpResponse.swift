/// Construye respuestas HTTP/1.1 simples y finales (el servidor cierra la conexión después).
enum HttpResponse {
    static func make(status: String, extraHeaders: [String] = [], body: String = "", includeBody: Bool = true) -> [UInt8] {
        let bodyBytes = Array(body.utf8)
        let headers = ["HTTP/1.1 \(status)"] + extraHeaders + ["Content-Length: \(bodyBytes.count)", "Connection: close"]
        let head = Array((headers.joined(separator: "\r\n") + "\r\n\r\n").utf8)
        return includeBody ? head + bodyBytes : head
    }

    static func badRequest() -> [UInt8] {
        make(status: "400 Bad Request")
    }
}
