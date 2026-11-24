// swift-tools-version: 6.4

import PackageDescription

/// Remote packages are limited to the approved, pinned set and use `from:`, so shared
/// transitive packages resolve within one major. Logging, ServiceLifecycle and NIO
/// arrive through them; declaring one directly widens the approved set.
let package = Package(
    name: "Server",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Packages/WardAxisManagementAPI"),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.27.1"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket", from: "2.8.1"),
        .package(url: "https://github.com/vapor/postgres-nio", from: "1.33.1"),
        // Test-only: the TLS suites mint a throwaway CA and leaf certificates per run.
        .package(url: "https://github.com/apple/swift-asn1", from: "1.7.3"),
        .package(url: "https://github.com/apple/swift-certificates", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "4.5.2")
    ],
    targets: [
        .executableTarget(
            name: "Server",
            dependencies: [
                "ServerCore"
            ]
        ),
        .target(
            name: "ServerCore",
            dependencies: [
                .product(name: "WardAxisAPIServer", package: "WardAxisManagementAPI"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTLS", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
                .product(name: "PostgresNIO", package: "postgres-nio")
            ],
            exclude: ["Resources/APIDocs/PROVENANCE.md"],
            // The contract is a symlink into WardAxisManagementAPI and is embedded, so the served
            // bytes are the built ones. The 1 MB script is a bundle resource instead, which
            // the Dockerfile copies next to the binary.
            resources: [
                .embedInCode("Resources/APIDocs/openapi.yaml"),
                .copy("Resources/APIDocs/redoc.standalone.js"),
                .copy("Resources/APIDocs/redoc-LICENSE.txt"),
                .copy("Resources/APIDocs/redoc.standalone.js.LICENSE.txt")
            ]
        ),
        .testTarget(
            name: "ServerTests",
            dependencies: [
                "ServerCore",
                .product(name: "WardAxisAPIFixtures", package: "WardAxisManagementAPI"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "HummingbirdWSClient", package: "hummingbird-websocket"),
                .product(name: "HummingbirdWSTesting", package: "hummingbird-websocket"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SwiftASN1", package: "swift-asn1"),
                .product(name: "X509", package: "swift-certificates")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
