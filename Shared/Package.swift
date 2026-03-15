// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "InchShared", targets: ["InchShared"])
    ],
    targets: [
        .target(
            name: "InchShared",
            path: "Sources/InchShared",
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
