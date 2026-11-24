// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "WardAxisManagementAPI",
    // macOS 14 is Hummingbird 2's floor, so the server package can depend on this one.
    platforms: [.macOS(.v14), .iOS(.v26), .tvOS(.v26)],
    products: [
        .library(name: "WardAxisAPIServer", targets: ["WardAxisAPIServer"]),
        .library(name: "WardAxisAPIClient", targets: ["WardAxisAPIClient"]),
        // Golden config-stream frames for the contract, server and app test suites; link it from test
        // targets only. Static, so a hosted test bundle carries it without a framework to embed.
        .library(name: "WardAxisAPIFixtures", type: .static, targets: ["WardAxisAPIFixtures"])
    ],
    dependencies: [
        // 1.13.1 and 1.14.0 emit UnusedImportAccess warnings in generated sources (apple/swift-openapi-generator#946);
        // stay exact until a release ships #947.
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.13.0"),
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
        .target(
            name: "WardAxisAPIFixtures",
            resources: [.copy("Frames")]
        ),
        .testTarget(
            name: "WardAxisAPITests",
            dependencies: ["WardAxisAPIClient", "WardAxisAPIFixtures"]
        )
    ],
    swiftLanguageModes: [.v6]
)
