// swift-tools-version: 6.0
import PackageDescription

// agent-frontier / harness — the JSCore probe for AGENT-P0.
//
// A self-contained Swift package with NO heavy dependencies: it links only the
// system JavaScriptCore + Foundation. This is deliberate — the harness is the
// scoring primitive for "can a small model write JS that runs?" and must build
// and self-test in seconds, independent of CoreAIKit / the model stack.
//
//   CJSWatchdog  — C shim exposing JSContextGroupSetExecutionTimeLimit (a private
//                  JSC API, exported from the binary but absent from the Swift
//                  module map) so runaway generated code is terminated, not hung.
//   JSProbeCore  — the library: run candidate JS in a sandboxed JSContext with the
//                  watchdog, capture stdout/exceptions, deep-equal the return value
//                  against expected test vectors. Also the ```js extraction parser
//                  and prompt builder.
//   jsprobe      — the CLI: run | grade | selftest | extract subcommands.
let package = Package(
    name: "jsprobe",
    // iOS is declared for the AgentRunCore library only — the on-device agent app
    // (agent-frontier/ondevice/AgentBench) depends on that Foundation-only product to run the
    // SAME loop/tools/checker on iPhone (P3a). The jsprobe/agentrun executables link
    // JavaScriptCore + use Process() and are never built for iOS (nothing iOS depends on them).
    platforms: [.macOS("13.0"), .iOS("26.0")],
    products: [
        // Exposed so the Phase B model driver (a separate package that also pulls
        // CoreAIKit) can grade completions in-process with the exact same sandbox.
        .library(name: "JSProbeCore", targets: ["JSProbeCore"]),
        // The Tier-A/D agent runner core (loop + mock tools + trace + checker),
        // dependency-free (Foundation only) so it self-tests on CPU in seconds.
        .library(name: "AgentRunCore", targets: ["AgentRunCore"]),
    ],
    targets: [
        .target(
            name: "CJSWatchdog",
            path: "Sources/CJSWatchdog"
        ),
        .target(
            name: "JSProbeCore",
            dependencies: ["CJSWatchdog"],
            path: "Sources/JSProbeCore"
        ),
        .executableTarget(
            name: "jsprobe",
            dependencies: ["JSProbeCore"],
            path: "Sources/jsprobe",
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
        // AgentRunCore — Tier-A/D tool-calling agent probe. No JavaScriptCore, no
        // CoreAIKit: the mock/null brains are pure computation, so the harness builds
        // and self-tests without the model stack (mirrors JSProbeCore's discipline).
        .target(
            name: "AgentRunCore",
            path: "Sources/AgentRunCore",
            // Synchronous, single-threaded harness (a tool catalog of closures + a run
            // loop). The Swift 6 strict-concurrency checks add no safety here, so this
            // target uses the v5 language mode — same spirit as JSProbeCore staying lean.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // CodeActCore — the CodeAct arm: run ONE model-written JS program in the P0 JSCore
        // sandbox with AgentRunCore's mock device tools bridged in as host functions. It
        // REUSES the P0 probe: CJSWatchdog (the runaway-kill watchdog) + JSProbeCore's
        // extractor. Scored by the SAME AgentRunCore checker as the tool-calling arm, so
        // the two arms are apples-to-apples on the same tasks.
        .target(
            name: "CodeActCore",
            dependencies: ["CJSWatchdog", "JSProbeCore", "AgentRunCore"],
            path: "Sources/CodeActCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "agentrun",
            dependencies: ["AgentRunCore", "CodeActCore", "JSProbeCore"],
            path: "Sources/agentrun",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
    ]
)
