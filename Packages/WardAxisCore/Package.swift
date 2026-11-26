// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "WardAxisCore",
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
    products: [
        .library(name: "WardAxisCore", targets: ["WardAxisCore"]),
        // Deterministic stand-ins for the sources in WardAxisCore. Every event
        // they emit is labeled `synthetic`; link from tests and previews only.
        .library(name: "WardAxisCoreSynthetic", targets: ["WardAxisCoreSynthetic"])
    ],
    targets: [
        .target(name: "WardAxisCore"),
        .target(name: "WardAxisCoreSynthetic", dependencies: ["WardAxisCore"]),
        .testTarget(
            name: "WardAxisCoreTests",
            dependencies: ["WardAxisCore", "WardAxisCoreSynthetic"],
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v6]
)
