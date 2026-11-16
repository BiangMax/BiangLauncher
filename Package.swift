// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BiangLauncher",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "BiangLauncher", targets: ["BiangLauncher"])],
    targets: [
        .target(name: "LauncherCore"),
        .executableTarget(name: "BiangLauncher", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"])
    ],
    swiftLanguageModes: [.v5]
)
