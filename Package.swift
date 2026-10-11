// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Breezeline",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Breezeline", exclude: ["Resources"]),
    ]
)
