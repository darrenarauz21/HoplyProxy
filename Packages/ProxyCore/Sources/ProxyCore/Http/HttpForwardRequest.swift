import Foundation

/// Reescribe una solicitud con URL absoluta para enviarla directamente al servidor de destino.
/// Elimina los encabezados dirigidos al proxy y fuerza `Connection: close`, de modo que cada
/// conexión de la laptop sirva a un solo destino.
enum HttpForwardRequest {
    private static let alwaysRemovedHeaders: Set<String> = [
        "connection", "proxy-connection", "proxy-authorization", "keep-alive", "te", "trailer", "upgrade",
    ]
    private static let lineTerminator: [UInt8] = Array("\r\n".utf8)

    static func make(from head: HttpRequestHead, authority: String, originTarget: String) -> [UInt8] {
        let removed = alwaysRemovedHeaders.union(connectionOptionNames(in: head))
        var bytes = Array("\(head.method) \(originTarget) \(head.version)".utf8) + lineTerminator

        if head.value(forHeader: "Host") == nil {
            bytes += Array("Host: \(authority)".utf8) + lineTerminator
        }
        for header in head.headers where !removed.contains(header.name.lowercased()) {
            bytes += header.rawLine + lineTerminator
        }
        bytes += Array("Connection: close".utf8) + lineTerminator + lineTerminator
        return bytes
    }

    /// Encabezados que el cliente marcó como propios de este salto en `Connection`.
    private static func connectionOptionNames(in head: HttpRequestHead) -> Set<String> {
        let values = head.headers.filter { $0.hasName("Connection") || $0.hasName("Proxy-Connection") }.map(\.value)
        let names = values.flatMap { $0.split(separator: ",") }.map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        return Set(names.filter { !$0.isEmpty })
    }
}
