// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "WardAxisPolicy",
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
    products: [
        .library(name: "WardAxisPolicy", targets: ["WardAxisPolicy"]),
        // Fixture-backed policy source; link from tests and previews only.
        .library(name: "WardAxisPolicyTestSupport", targets: ["WardAxisPolicyTestSupport"])
    ],
    dependencies: [
        .package(path: "../WardAxisCore")
    ],
    targets: [
        .target(
            name: "WardAxisPolicy",
            dependencies: [.product(name: "WardAxisCore", package: "WardAxisCore")]
        ),
        .target(
            name: "WardAxisPolicyTestSupport",
            dependencies: ["WardAxisPolicy", .product(name: "WardAxisCore", package: "WardAxisCore")]
        ),
        .testTarget(
            name: "WardAxisPolicyTests",
            dependencies: [
                "WardAxisPolicy",
                "WardAxisPolicyTestSupport",
                .product(name: "WardAxisCore", package: "WardAxisCore"),
                // SeededGenerator: one SplitMix64 for every seeded property test.
                .product(name: "WardAxisCoreSynthetic", package: "WardAxisCore")
            ],
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v6]
)
