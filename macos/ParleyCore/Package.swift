// swift-tools-version: 6.0
// The parts of the native shell that are logic, not windows: the JSON-RPC
// wire to the engine, key-code mapping, the HUD phase → recorder rules and
// the pasteboard round trip. Kept in a package so `swift test` covers them
// without launching the app.
import PackageDescription

let package = Package(
    name: "ParleyCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "ParleyCore", targets: ["ParleyCore"]),
    ],
    targets: [
        .target(name: "ParleyCore"),
        .testTarget(name: "ParleyCoreTests", dependencies: ["ParleyCore"]),
    ]
)
