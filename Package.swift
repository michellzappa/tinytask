// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TinyTask",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "Packages/TinyKit"),
    ],
    targets: [
        .executableTarget(
            name: "TinyTask",
            dependencies: [
                .product(name: "TinyKit", package: "TinyKit"),
            ],
            path: "Sources/TinyTask",
            exclude: ["Resources", "Info.plist"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "TinyTaskTests",
            dependencies: ["TinyTask"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
