// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AugmentFoundation", platforms: [.macOS(.v14)], targets: [
    .target(name: "DockMagic", path: "Sources"),
    .testTarget(name: "AugmentTests", dependencies: ["DockMagic"], path: "Tests")
])
