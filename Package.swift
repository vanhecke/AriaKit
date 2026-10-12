// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("ExistentialAny"),
  .swiftLanguageMode(.v6),
]

/// libaria2 is C++. Every module that imports AriaKit needs this setting too.
let cxxInterop: [SwiftSetting] = [.interoperabilityMode(.Cxx)]

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
      swiftSettings: swiftSettings + cxxInterop,
    ),
    .executableTarget(
      name: "AriaKitCLI",
      dependencies: [
        "AriaKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Configuration", package: "swift-configuration"),
      ],
      exclude: ["AGENTS.md"],
      swiftSettings: swiftSettings + cxxInterop,
    ),
    .testTarget(
      name: "AriaKitTests",
      dependencies: ["AriaKit"],
      swiftSettings: swiftSettings + cxxInterop,
    ),
    .testTarget(
      name: "AriaKitCLITests",
      dependencies: ["AriaKitCLI"],
      exclude: ["AGENTS.md"],
      swiftSettings: swiftSettings + cxxInterop,
    ),
  ],
)
