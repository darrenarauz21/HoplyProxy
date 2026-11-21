// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProxyCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "ProxyCore", targets: ["ProxyCore"]),
    ],
    targets: [
        .target(name: "Socks5"),
        .target(name: "ProxyCore", dependencies: ["Socks5"]),
        .testTarget(name: "Socks5Tests", dependencies: ["Socks5"]),
        .testTarget(name: "ProxyCoreTests", dependencies: ["ProxyCore", "Socks5"]),
    ]
)
