/// Respuestas del servidor PAC integrado. El archivo se sirve en el mismo puerto que
/// el proxy, así la laptop solo necesita un reenvío (USB) o una dirección (Wi-Fi).
enum PacHttpResponse {
    static let pacPath = "/proxy.pac"

    static func response(for head: HttpRequestHead, proxyHost: String, port: UInt16) -> [UInt8] {
        let isHead = head.method == "HEAD"
        guard head.method == "GET" || isHead else {
            return HttpResponse.make(status: "405 Method Not Allowed", extraHeaders: ["Allow: GET, HEAD"])
        }
        guard head.path == pacPath else {
            return HttpResponse.make(status: "404 Not Found")
        }
        let script = PacScriptGenerator.script(proxyHost: proxyHost, port: port)
        return HttpResponse.make(
            status: "200 OK",
            extraHeaders: ["Content-Type: application/x-ns-proxy-autoconfig", "Cache-Control: no-store"],
            body: script,
            includeBody: !isHead
        )
    }
}
