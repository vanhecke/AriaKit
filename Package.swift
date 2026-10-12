// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("ExistentialAny"),
  .swiftLanguageMode(.v6),
]

let package = Package(
  name: "AriaKit",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "AriaKit", targets: ["AriaKit"]),
    .executable(name: "ariakit", targets: ["AriaKitCLI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.2.2"),
  ],
  targets: [
    .systemLibrary(
      name: "Clibaria2",
      pkgConfig: "libaria2",
      providers: [.apt(["libaria2-0-dev"])],
    ),
    .target(
      name: "AriaShim",
      dependencies: ["Clibaria2"],
    ),
    .target(
      name: "AriaKit",
      dependencies: ["AriaShim"],
      swiftSettings: swiftSettings,
    ),
    .executableTarget(
      name: "AriaKitCLI",
      dependencies: [
        "AriaKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Configuration", package: "swift-configuration"),
      ],
      swiftSettings: swiftSettings,
    ),
    .testTarget(
      name: "AriaKitTests",
      dependencies: ["AriaKit"],
      swiftSettings: swiftSettings,
    ),
    .testTarget(
      name: "AriaKitCLITests",
      dependencies: ["AriaKitCLI"],
      swiftSettings: swiftSettings,
    ),
  ],
)
