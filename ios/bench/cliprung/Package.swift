// swift-tools-version: 6.0
import PackageDescription

// The CLIP rung's A/B harness (playbook spec E). Native macOS, deliberately
// outside the app's build graph: CoreAI.framework ships in the macOS 27 and
// iphoneos 27 SDKs but NOT in the Mac Catalyst iOSSupport tree, so the
// Catalyst app — the whole Mac bench/stage lane — cannot link it. In-app CLIP
// is device-only; the measurement is this executable.
let package = Package(
    name: "cliprung",
    platforms: [.macOS("27.0")],
    dependencies: [
        // Sibling checkout: ~/code/coreai-kit next to ~/code/edge-agent-lab.
        // Needs the Xcode 27 beta's toolchain — the default `swift` cannot see
        // CoreAI (DEVELOPER_DIR=/Applications/Xcode-27.0.0-Beta.5.app/…).
        .package(path: "../../../../coreai-kit")
    ],
    targets: [
        .executableTarget(
            name: "cliprung",
            dependencies: [
                .product(name: "CoreAIKitVision", package: "coreai-kit")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
