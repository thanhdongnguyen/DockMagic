// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "OpenCodeFoundation", platforms: [.macOS(.v14)], targets: [
    .target(name: "DockMagic", path: "Sources", linkerSettings: [.linkedLibrary("sqlite3")]),
    .testTarget(name: "OpenCodeTests", dependencies: ["DockMagic"], path: "Tests")
])
