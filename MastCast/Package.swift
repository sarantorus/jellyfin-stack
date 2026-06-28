// swift-tools-version:5.9
import PackageDescription

// SPM package for the pure-logic core (engine, models, protocol definitions) so it
// builds and unit-tests on any platform / CI without Xcode. The full app (SwiftUI,
// Google Cast SDK, ffmpeg-kit) lives in the Xcode project that includes these same
// sources; the SwiftUI entry point under MastCast/App is excluded here because it
// can't compile on non-Apple platforms.
let package = Package(
    name: "MastCast",
    products: [
        .library(name: "MastCast", targets: ["MastCast"]),
    ],
    targets: [
        .target(
            name: "MastCast",
            path: "MastCast",
            exclude: ["App"]
        ),
        .testTarget(
            name: "MastCastTests",
            dependencies: ["MastCast"],
            path: "Tests"
        ),
    ]
)
