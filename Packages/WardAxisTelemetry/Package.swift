// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "WardAxisTelemetry",
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
    products: [
        .library(name: "WardAxisTelemetry", targets: ["WardAxisTelemetry"])
    ],
    targets: [
        .target(name: "WardAxisTelemetry"),
        .testTarget(name: "WardAxisTelemetryTests", dependencies: ["WardAxisTelemetry"])
    ],
    swiftLanguageModes: [.v6]
)
