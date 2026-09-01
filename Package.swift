// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SwapAlert",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SwapAlert", targets: ["SwapAlert"]),
        .executable(name: "IconGenerator", targets: ["IconGenerator"])
    ],
    targets: [
        .executableTarget(name: "SwapAlert"),
        .executableTarget(name: "IconGenerator", path: "Tools/IconGenerator"),
        .testTarget(name: "SwapAlertTests", dependencies: ["SwapAlert"])
    ]
)
