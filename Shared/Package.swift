// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "InchShared", targets: ["InchShared"])
    ],
    targets: [
        .target(
            name: "InchShared",
            path: "Sources/InchShared",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "InchSharedTests",
            dependencies: ["InchShared"],
            path: "Tests/InchSharedTests"
        )
    ]
)
