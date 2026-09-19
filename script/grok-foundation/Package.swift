// swift-tools-version: 5.9
import PackageDescription

// Staged by test_grok_foundation.sh. Compiles the production files, not copies
// of their implementations, without the app's Sparkle/SwiftTerm dependencies.
let package = Package(
    name: "DockMagicGrokFoundation",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DockMagic", path: "Sources"),
        .testTarget(name: "GrokFoundationTests", dependencies: ["DockMagic"], path: "Tests"),
    ]
)
