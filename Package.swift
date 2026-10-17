// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AndroidFT",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(
            name: "CMTP",
            path: "Sources/CMTP",
            pkgConfig: "libmtp",
            providers: [.brew(["libmtp"])]
        ),
        .executableTarget(
            name: "AndroidFT",
            dependencies: ["CMTP"],
            path: "Sources/AndroidFT",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
        .testTarget(
            name: "AndroidFTTests",
            dependencies: ["AndroidFT"],
            path: "Tests/AndroidFTTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
