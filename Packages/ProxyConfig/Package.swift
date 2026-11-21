// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProxyConfig",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "ProxyConfig", targets: ["ProxyConfig"]),
    ],
    dependencies: [
        .package(path: "../ProxyCore"),
    ],
    targets: [
        .target(name: "ProxyConfig", dependencies: [.product(name: "ProxyCore", package: "ProxyCore")]),
        .testTarget(
            name: "ProxyConfigTests",
            dependencies: ["ProxyConfig", .product(name: "ProxyCore", package: "ProxyCore")]
        ),
    ]
)
