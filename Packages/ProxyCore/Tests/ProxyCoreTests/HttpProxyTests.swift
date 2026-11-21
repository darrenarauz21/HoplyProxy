import Socks5
import XCTest
@testable import ProxyCore

final class HttpProxyTests: XCTestCase {
    // MARK: - Destinos

    func testParsesAuthorityForms() {
        XCTAssertEqual(
            HttpAuthority.destination(from: "example.com:443", defaultPort: nil),
            Socks5Destination(address: .domain("example.com"), port: 443)
        )
        XCTAssertEqual(
            HttpAuthority.destination(from: "10.0.0.1", defaultPort: 80),
            Socks5Destination(address: .ipv4([10, 0, 0, 1]), port: 80)
        )
        XCTAssertEqual(
            HttpAuthority.destination(from: "[::1]:8443", defaultPort: nil),
            Socks5Destination(address: .ipv6(Array(repeating: 0, count: 15) + [1]), port: 8443)
        )
    }

    func testRejectsInvalidAuthorities() {
        let samples = ["example.com", "example.com:0", "example.com:70000", "exa mple.com:80", "a:b:c", "[::1", "[::1]x", ":443"]
        for sample in samples {
            XCTAssertNil(HttpAuthority.destination(from: sample, defaultPort: nil), sample)
        }
    }

    // MARK: - Rutas

    func testResolvesConnectAsTunnel() throws {
        let route = try HttpProxyRoute.resolve(head("CONNECT example.com:443"))

        XCTAssertEqual(route, .tunnel(Socks5Destination(address: .domain("example.com"), port: 443)))
    }

    func testResolvesAbsoluteUrlAsForward() throws {
        let route = try HttpProxyRoute.resolve(head("GET http://Example.com:8080/a/b?c=1#frag"))

        XCTAssertEqual(route, .forward(
            destination: Socks5Destination(address: .domain("Example.com"), port: 8080),
            authority: "Example.com:8080",
            originTarget: "/a/b?c=1"
        ))
    }

    func testForwardDefaultsToRootPathAndPort80() throws {
        let route = try HttpProxyRoute.resolve(head("GET http://example.com"))

        XCTAssertEqual(route, .forward(
            destination: Socks5Destination(address: .domain("example.com"), port: 80),
            authority: "example.com",
            originTarget: "/"
        ))
    }

    func testResolvesOriginFormAsLocalResource() throws {
        XCTAssertEqual(try HttpProxyRoute.resolve(head("GET /proxy.pac")), .localResource)
    }

    func testRejectsUnsupportedTargets() {
        let samples = ["GET https://example.com/", "GET http://user@example.com/", "GET example.com", "CONNECT example.com"]
        for sample in samples {
            XCTAssertThrowsError(try HttpProxyRoute.resolve(head(sample)), sample)
        }
    }

    // MARK: - Reenvío

    func testForwardRequestRemovesProxyHeadersAndForcesClose() throws {
        let request = try head(
            "GET http://example.com/x",
            headers: ["Host: example.com", "Proxy-Authorization: Basic abc", "Proxy-Connection: keep-alive, X-Hop", "X-Hop: 1", "Accept: */*"]
        )

        let forwarded = String(decoding: HttpForwardRequest.make(from: request, authority: "example.com", originTarget: "/x"), as: UTF8.self)

        XCTAssertEqual(forwarded, "GET /x HTTP/1.1\r\nHost: example.com\r\nAccept: */*\r\nConnection: close\r\n\r\n")
    }

    func testForwardRequestAddsMissingHost() throws {
        let request = try head("GET http://example.com:8080/", headers: [])

        let forwarded = String(decoding: HttpForwardRequest.make(from: request, authority: "example.com:8080", originTarget: "/"), as: UTF8.self)

        XCTAssertEqual(forwarded, "GET / HTTP/1.1\r\nHost: example.com:8080\r\nConnection: close\r\n\r\n")
    }

    // MARK: - Autenticación

    func testParsesBasicAuthorization() {
        let encoded = Data("usuario:clave:con:dos-puntos".utf8).base64EncodedString()

        let authorization = HttpProxyAuthorization.parse("Basic \(encoded)")

        XCTAssertEqual(authorization?.username, Array("usuario".utf8))
        XCTAssertEqual(authorization?.password, Array("clave:con:dos-puntos".utf8))
    }

    func testRejectsInvalidAuthorization() {
        XCTAssertNil(HttpProxyAuthorization.parse("Bearer abc"))
        XCTAssertNil(HttpProxyAuthorization.parse("Basic ***"))
        XCTAssertNil(HttpProxyAuthorization.parse("Basic \(Data("sin-separador".utf8).base64EncodedString())"))
    }

    // MARK: - Respuestas

    func testMapsOutboundErrorsToStatusCodes() {
        XCTAssertTrue(text(HttpProxyResponse.failure(for: .timedOut)).hasPrefix("HTTP/1.1 504"))
        XCTAssertTrue(text(HttpProxyResponse.failure(for: .connectionRefused)).hasPrefix("HTTP/1.1 502"))
        XCTAssertTrue(text(HttpProxyResponse.failure(for: .invalidDestination)).hasPrefix("HTTP/1.1 400"))
    }

    func testAuthenticationChallengeUsesBasic() {
        XCTAssertTrue(text(HttpProxyResponse.authenticationRequired()).contains("Proxy-Authenticate: Basic realm=\"Hoply\""))
    }

    // MARK: - Ayudantes

    private func head(_ requestLine: String, headers: [String] = ["Host: x"]) throws -> HttpRequestHead {
        let lines = ["\(requestLine) HTTP/1.1"] + headers
        let bytes = Array((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
        return try XCTUnwrap(try HttpRequestHead.parse(bytes))
    }

    private func text(_ bytes: [UInt8]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }
}
