// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AppDesign",
    platforms: [
        .iOS(.v26), .macOS(.v26), .tvOS(.v26), .visionOS(.v26)
    ],
    products: [
        .library(name: "AppDesign", targets: ["AppDesign"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.1"),
    ],
    targets: [
        .target(
            name: "AppDesign",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS])),
            ]
        )
    ]
)
