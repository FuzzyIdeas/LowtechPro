// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LowtechPro",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LowtechPro",
            targets: ["LowtechPro"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/FuzzyIdeas/Lowtech", branch: "main"),
        .package(url: "https://github.com/alin23/PaddleSPM", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LowtechPro",
            dependencies: [
                .product(name: "Lowtech", package: "Lowtech"),
                .product(name: "Paddle", package: "PaddleSPM"),
            ]
        ),
    ]
)
