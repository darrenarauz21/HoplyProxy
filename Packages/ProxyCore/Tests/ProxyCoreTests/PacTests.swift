import XCTest
@testable import ProxyCore

final class PacTests: XCTestCase {
    func testParsesRequestLineAndDropsQuery() throws {
        let bytes = Array("GET /proxy.pac?v=1 HTTP/1.1\r\nHost: x\r\n\r\n".utf8)

        let head = try XCTUnwrap(try HttpRequestHead.parse(bytes))

        XCTAssertEqual(head.method, "GET")
        XCTAssertEqual(head.path, "/proxy.pac")
        XCTAssertEqual(head.value(forHeader: "host"), "x")
        XCTAssertEqual(head.byteCount, bytes.count)
    }

    func testWaitsForCompleteHead() throws {
        XCTAssertNil(try HttpRequestHead.parse(Array("GET /proxy.pac HTTP/1.1\r\nHost: x\r\n".utf8)))
    }

    func testRejectsMalformedRequestLine() {
        let samples = [
            "get /proxy.pac HTTP/1.1\r\n\r\n",
            "GET /proxy.pac\r\n\r\n",
            "GET /a HTTP/2\r\n\r\n",
            "GET /a HTTP/1.1\r\nSin separador\r\n\r\n",
            "GET /a HTTP/1.1\r\n plegado: x\r\n\r\n",
            "GET /a HTTP/1.1\r\nHost: a\u{01}b\r\n\r\n",
        ]
        for sample in samples {
            XCTAssertThrowsError(try HttpRequestHead.parse(Array(sample.utf8)), sample)
        }
    }

    func testServesPacForGet() throws {
        let response = text(PacHttpResponse.response(for: try head("GET /proxy.pac"), proxyHost: "192.168.1.5", port: 1080))

        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(response.contains("Content-Type: application/x-ns-proxy-autoconfig"))
        XCTAssertTrue(response.contains("return \"PROXY 192.168.1.5:1080; SOCKS5 192.168.1.5:1080\";"))
    }

    func testHeadOmitsBody() throws {
        let response = text(PacHttpResponse.response(for: try head("HEAD /proxy.pac"), proxyHost: "127.0.0.1", port: 1080))

        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200 OK"))
        XCTAssertTrue(response.hasSuffix("\r\n\r\n"))
    }

    func testRejectsOtherPathsAndMethods() throws {
        let notFound = text(PacHttpResponse.response(for: try head("GET /"), proxyHost: "h", port: 1))
        let notAllowed = text(PacHttpResponse.response(for: try head("POST /proxy.pac"), proxyHost: "h", port: 1))

        XCTAssertTrue(notFound.hasPrefix("HTTP/1.1 404"))
        XCTAssertTrue(notAllowed.hasPrefix("HTTP/1.1 405"))
    }

    func testBuildsPacUrl() {
        XCTAssertEqual(PacScriptGenerator.url(proxyHost: "127.0.0.1", port: 1080), "http://127.0.0.1:1080/proxy.pac")
    }

    private func head(_ requestLine: String) throws -> HttpRequestHead {
        try XCTUnwrap(try HttpRequestHead.parse(Array("\(requestLine) HTTP/1.1\r\nHost: x\r\n\r\n".utf8)))
    }

    private func text(_ bytes: [UInt8]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }
}
