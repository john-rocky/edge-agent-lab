import Foundation

// Manifest — byproduct ② from the kickoff: the JS-bridge manifest, a declarative
// capability + permission ledger. The kickoff's thesis is that on iOS the set of
// host functions you JSExport into the JavaScriptCore sandbox *is* the agent's
// permission model (App Store rule 2.5.2 makes JSCore the only legal path to run
// generated code, so the bridge choice = the security boundary). This manifest is
// that boundary written down.
//
// It is generated FROM the tool catalog so the declared surface cannot drift from the
// executed surface. ENFORCEMENT is deliberately out of scope here — the deliverable is
// the *format* (a third party can adopt it; SWE-bench logic). Nothing consumes it yet.
public enum Manifest {

    public static let version = "0.1"

    /// Build the manifest for a set of tool names (a task's allowlist, or the whole catalog).
    public static func build(toolNames: [String]) -> JSONValue {
        let specs = toolNames.compactMap { Tools.catalog[$0] }
        let caps: [JSONValue] = specs.map { t in
            let params: [JSONValue] = t.params.map { p in
                .object([
                    "name": .string(p.name),
                    "type": .string(p.type),
                    "required": .bool(p.required),
                    "about": .string(p.about),
                ])
            }
            return .object([
                "name": .string(t.name),
                "summary": .string(t.summary),
                "permission": .object([
                    "domain": .string(t.permission.domain),
                    "access": .string(t.permission.access),
                    "user_consent": .string(t.permission.userConsent),
                ]),
                "side_effects": .bool(t.sideEffects),
                "params": .array(params),
            ])
        }
        // The permission domains this manifest touches, and whether any tool can mutate.
        let domains = Array(Set(specs.map { $0.permission.domain })).sorted()
        let writes = specs.contains { $0.sideEffects }
        return .object([
            "manifest_version": .string(version),
            "runtime": .object([
                "engine": .string("JavaScriptCore"),
                "network": .bool(false),
                "filesystem": .bool(false),
                "timers": .bool(false),
                "timeout_ms_default": .int(2000),
                "notes": .string("Only the capabilities below are JSExported into the sandbox. Absent capabilities are unreachable, not merely disallowed."),
            ]),
            "grants": .object([
                "domains": .array(domains.map { .string($0) }),
                "can_write": .bool(writes),
                "consent_model": .string("per-session grant per domain; a per-call prompt is a stricter variant a host may choose"),
            ]),
            "capabilities": .array(caps),
        ])
    }
}
