// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "WardAxisManagement",
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
    products: [
        .library(name: "WardAxisManagement", targets: ["WardAxisManagement"]),
        // Doubles for the seams below; link from test targets only.
        .library(name: "WardAxisManagementTestSupport", targets: ["WardAxisManagementTestSupport"])
    ],
    dependencies: [
        .package(path: "../WardAxisCore"),
        .package(path: "../WardAxisTelemetry"),
        .package(path: "../WardAxisManagementAPI")
    ],
    targets: [
        .target(
            name: "WardAxisManagement",
            dependencies: [
                .product(name: "WardAxisCore", package: "WardAxisCore"),
                .product(name: "WardAxisTelemetry", package: "WardAxisTelemetry"),
                .product(name: "WardAxisAPIClient", package: "WardAxisManagementAPI")
            ]
        ),
        .target(
            name: "WardAxisManagementTestSupport",
            dependencies: ["WardAxisManagement"]
        ),
        .testTarget(
            name: "WardAxisManagementTests",
            dependencies: [
                "WardAxisManagement",
                "WardAxisManagementTestSupport",
                .product(name: "WardAxisAPIFixtures", package: "WardAxisManagementAPI")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
