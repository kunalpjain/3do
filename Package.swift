// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThreeDo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        // Pure business logic — no UI frameworks, no GRDB
        .target(
            name: "ThreeDoCore",
            dependencies: [],
            path: "Sources/ThreeDoCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        // macOS app — UI + GRDB
        .executableTarget(
            name: "ThreeDo",
            dependencies: [
                "ThreeDoCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/ThreeDo",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        // Unit tests for pure logic — built as an executable so `swift run ThreeDoTests`
        // works without Xcode (CLT-only environments can't run .xctest bundles).
        .executableTarget(
            name: "ThreeDoTests",
            dependencies: ["ThreeDoCore"],
            path: "Tests/ThreeDoTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
