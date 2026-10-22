// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "JSONQuery",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "JSONQuery", targets: ["JSONQuery"])
    ],
    dependencies: [
        .package(path: "../swift-foundation-extensions")
    ],
    targets: [
        .target(
            name: "JSONQuery", dependencies: [.product(name: "ProcessRunner", package: "swift-foundation-extensions")],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "JSONQueryTests", dependencies: ["JSONQuery"], path: "Tests"),
    ]
)
