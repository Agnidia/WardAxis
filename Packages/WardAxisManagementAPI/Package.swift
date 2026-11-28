// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "WardAxisManagementAPI",
    // macOS 26 matches the app floor; Server/Package.swift declares the same floor so it can depend on this package.
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
    products: [
        .library(name: "WardAxisAPIServer", targets: ["WardAxisAPIServer"]),
        .library(name: "WardAxisAPIClient", targets: ["WardAxisAPIClient"]),
        // Hand-written values the generator does not emit; the server and the client both link it (ADR 0019).
        .library(name: "WardAxisAPIContract", targets: ["WardAxisAPIContract"]),
        // Golden config-stream frames for the contract, server and app test suites; link it from test
        // targets only. Static, so a hosted test bundle carries it without a framework to embed.
        .library(name: "WardAxisAPIFixtures", type: .static, targets: ["WardAxisAPIFixtures"])
    ],
    dependencies: [
        // 1.14.0 emits UnusedImportAccess warnings in generated sources (apple/swift-openapi-generator#946).
        // The warnings are accepted to stay on the supported line; see ADR 0001.
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.14.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.13.0")
    ],
    targets: [
        .target(
            name: "WardAxisAPIServer",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .target(
            name: "WardAxisAPIClient",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .target(name: "WardAxisAPIContract"),
        .target(
            name: "WardAxisAPIFixtures",
            resources: [.copy("Frames")]
        ),
        .testTarget(
            name: "WardAxisAPITests",
            dependencies: ["WardAxisAPIClient", "WardAxisAPIContract", "WardAxisAPIFixtures"]
        )
    ],
    swiftLanguageModes: [.v6]
)
