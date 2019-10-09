// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "MDText",
    platforms: [
      .iOS(.v13),
      .macOS(.v10_15),
      .tvOS(.v13)
    ],
    products: [
        .library(
            name: "MDText",
            targets: ["MDText"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MDText",
            dependencies: []),
    ]
)