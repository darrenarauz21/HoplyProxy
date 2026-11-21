import Foundation

/// Cabecera de una solicitud HTTP/1.x: línea de solicitud y encabezados.
/// Conserva los bytes originales de cada encabezado para reenviarlos sin alterarlos.
struct HttpRequestHead: Equatable {
    static let maximumHeaderCount = 100
    private static let headTerminator: [UInt8] = Array("\r\n\r\n".utf8)
    private static let lineTerminator: [UInt8] = Array("\r\n".utf8)
    private static let supportedVersions: Set<String> = ["HTTP/1.0", "HTTP/1.1"]

    let method: String
    /// Destino tal como lo envía el cliente: ruta, URL absoluta o `host:puerto`.
    let target: String
    let version: String
    let headers: [HttpHeaderField]
    /// Bytes que ocupa la cabecera, incluida la línea vacía final.
    let byteCount: Int

    /// Ruta sin la cadena de consulta, para destinos en forma de ruta.
    var path: String {
        String(target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    /// Valor del primer encabezado con ese nombre, sin distinguir mayúsculas.
    func value(forHeader name: String) -> String? {
        headers.first { $0.hasName(name) }?.value
    }

    /// Devuelve `nil` mientras no llegue la cabecera completa.
    static func parse(_ buffer: [UInt8]) throws -> HttpRequestHead? {
        guard let terminator = buffer.rangeOfPattern(headTerminator) else { return nil }
        let lines = buffer[..<terminator.lowerBound].splitLines(by: lineTerminator)
        guard let requestLine = lines.first else { throw HttpRequestError.malformed }

        let (method, target, version) = try parseRequestLine(requestLine)
        let headerLines = lines.dropFirst()
        guard headerLines.count <= maximumHeaderCount else { throw HttpRequestError.malformed }
        let headers = try headerLines.map(HttpHeaderField.parse)

        return HttpRequestHead(
            method: method,
            target: target,
            version: version,
            headers: headers,
            byteCount: terminator.upperBound
        )
    }

    /// Las solicitudes HTTP comienzan con el nombre del método en mayúsculas.
    static func isPossibleRequestStart(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
    }

    private static func parseRequestLine(_ bytes: ArraySlice<UInt8>) throws -> (String, String, String) {
        guard bytes.allSatisfy({ (0x20..<0x7F).contains($0) }) else { throw HttpRequestError.malformed }
        let parts = String(decoding: bytes, as: UTF8.self).split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 3,
              !parts[0].isEmpty,
              parts[0].allSatisfy({ $0.isASCII && $0.isUppercase }),
              !parts[1].isEmpty,
              supportedVersions.contains(String(parts[2])) else {
            throw HttpRequestError.malformed
        }
        return (String(parts[0]), String(parts[1]), String(parts[2]))
    }
}

/// Encabezado HTTP con su línea original.
struct HttpHeaderField: Equatable {
    let name: String
    let value: String
    /// Bytes de la línea sin el salto final.
    let rawLine: [UInt8]

    func hasName(_ candidate: String) -> Bool {
        name.caseInsensitiveCompare(candidate) == .orderedSame
    }

    /// Formato `nombre: valor`. Se rechazan caracteres de control y líneas plegadas obsoletas.
    static func parse(_ line: ArraySlice<UInt8>) throws -> HttpHeaderField {
        guard let colon = line.firstIndex(of: UInt8(ascii: ":")) else { throw HttpRequestError.malformed }
        let nameBytes = line[line.startIndex..<colon]
        let valueBytes = line[line.index(after: colon)...]
        guard !nameBytes.isEmpty,
              nameBytes.allSatisfy(isTokenByte),
              valueBytes.allSatisfy(isFieldValueByte) else {
            throw HttpRequestError.malformed
        }
        let value = String(decoding: valueBytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        return HttpHeaderField(name: String(decoding: nameBytes, as: UTF8.self), value: value, rawLine: Array(line))
    }

    /// Caracteres válidos en el nombre de un encabezado (`tchar` de RFC 9110).
    private static func isTokenByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "a")...UInt8(ascii: "z"),
             UInt8(ascii: "A")...UInt8(ascii: "Z"),
             UInt8(ascii: "0")...UInt8(ascii: "9"):
            return true
        default:
            return Array("!#$%&'*+-.^_`|~".utf8).contains(byte)
        }
    }

    /// Texto visible, espacio, tabulador o bytes no ASCII; nunca otros caracteres de control.
    private static func isFieldValueByte(_ byte: UInt8) -> Bool {
        byte == 0x09 || (byte >= 0x20 && byte != 0x7F)
    }
}

enum HttpRequestError: Error, Equatable {
    case malformed
}

extension Array where Element == UInt8 {
    func rangeOfPattern(_ pattern: [UInt8]) -> Range<Int>? {
        guard !pattern.isEmpty, count >= pattern.count else { return nil }
        for start in 0...(count - pattern.count) where self[start..<(start + pattern.count)].elementsEqual(pattern) {
            return start..<(start + pattern.count)
        }
        return nil
    }
}

private extension ArraySlice where Element == UInt8 {
    /// Divide por una secuencia de varios bytes, conservando segmentos vacíos.
    func splitLines(by separator: [UInt8]) -> [ArraySlice<UInt8>] {
        var segments: [ArraySlice<UInt8>] = []
        var segmentStart = startIndex
        var index = startIndex
        while index <= endIndex - separator.count {
            if self[index..<(index + separator.count)].elementsEqual(separator) {
                segments.append(self[segmentStart..<index])
                index += separator.count
                segmentStart = index
            } else {
                index += 1
            }
        }
        segments.append(self[segmentStart..<endIndex])
        return segments
    }
}
