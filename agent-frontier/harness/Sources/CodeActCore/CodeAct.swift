import Foundation
import JavaScriptCore
import CJSWatchdog
import AgentRunCore

// CodeAct — run ONE JS program (written by the model, or a reference program) that
// accomplishes a Tier-A/D task by calling the device tools directly, in a single round.
//
// This is the CodeAct arm of the kickoff's headline experiment (CodeAct vs tool-calling).
// It REUSES the P0 JSCore probe as the execution engine:
//   * CJSWatchdog — the runaway-kill watchdog (an infinite loop is terminated, not hung).
//   * the same console bridge + exception-capture pattern JSProbeCore uses.
// On top of that it JSExports AgentRunCore's mock tools as host functions, so the model's
// program can call `reminders_create({...})`, `corpus_read({...})`, etc. The resulting
// DeviceState is scored by the EXACT SAME AgentRunCore.Checker as the tool-calling arm —
// that identity is what makes the comparison fair.
//
// Tool naming: a tool `reminders.create` is exposed to JS as `reminders_create` (dots are
// not valid JS identifiers). Marshaling crosses the boundary as JSON strings (bulletproof
// vs NSNumber<->bool ambiguity); the JS wrapper JSON.stringifies args and JSON.parses the
// result, so the model just sees clean functions returning objects.

final class StateBox {
    var state: DeviceState
    var calls: [String] = []            // tool names, in call order
    var callArgs: [JSONValue] = []      // parallel to calls
    init(_ s: DeviceState) { state = s }
}
private final class LogBox { var s = "" }

public struct CodeActResult {
    public let ok: Bool
    public let checks: [CheckResult]
    public let logs: String
    public let defineError: String?
    public let callCount: Int
    public let wallMs: Double
    public let traceLines: [JSONValue]
    public let revisit: JSONValue
    public let stateSnapshot: JSONValue   // observable writable state after the run (NOT final_check)

    /// Feedback for the interactive (self-repair) loop. Deliberately grader-free: it exposes
    /// only what a real on-device agent could see for itself — the runtime error, the
    /// program's own printed output, and the writable state it produced (as if it called the
    /// read tools). It never reveals final_check's expected values. Each attempt runs on FRESH
    /// state, so this describes the previous attempt's outcome.
    public func feedback() -> String {
        var s = ""
        if let e = defineError { s += "Your program threw an error and stopped: \(e)\n" }
        else { s += "Your program ran without errors.\n" }
        s += "It made \(callCount) tool call(s).\n"
        let printed = logs.trimmingCharacters(in: .whitespacesAndNewlines)
        s += printed.isEmpty ? "It printed nothing (console.log).\n" : "It printed:\n\(printed)\n"
        s += "Device state your program produced (what the read tools would now show):\n\(stateSnapshot.jsonString())\n"
        return s
    }
}

public enum CodeAct {

    /// Run a CodeAct program `code` against `task`. `timeoutMs` is the watchdog budget for
    /// the whole program (default 3s — a program that loops forever is killed).
    public static func run(task: AgentTask, code: String, timeoutMs: Double = 3000) -> CodeActResult {
        let t0 = Date()
        let box = StateBox(DeviceState(task: task))
        let logs = LogBox()
        let tools = task.toolAllowlist.compactMap { Tools.catalog[$0] }

        let vm = JSVirtualMachine()!
        let ctx = JSContext(virtualMachine: vm)!
        let group = JSContextGetGroup(ctx.jsGlobalContextRef)
        cjs_set_time_limit(group, timeoutMs / 1000.0)

        // console.* -> captured buffer (the program's final console.log IS its "answer").
        let sink: @convention(block) (JSValue?) -> Void = { v in logs.s += (v?.toString() ?? "") + "\n" }
        ctx.setObject(sink, forKeyedSubscript: "__logSink" as NSString)
        ctx.evaluateScript("""
        var console = {
          log:   function(){ __logSink(Array.prototype.slice.call(arguments).join(' ')); },
          info:  function(){ __logSink(Array.prototype.slice.call(arguments).join(' ')); },
          warn:  function(){ __logSink(Array.prototype.slice.call(arguments).join(' ')); },
          error: function(){ __logSink(Array.prototype.slice.call(arguments).join(' ')); }
        };
        """)

        // Bridge each allowlisted tool as a native function taking/returning a JSON string.
        for spec in tools {
            let mangled = "__tool_" + spec.name.replacingOccurrences(of: ".", with: "_")
            let block: @convention(block) (String) -> String = { argsJSON in
                let args = JSONValue.parse(argsJSON) ?? .object([:])
                box.calls.append(spec.name)
                box.callArgs.append(args)
                let outcome = spec.run(args, &box.state)
                if let e = outcome.error { return JSONValue.object(["error": .string(e)]).jsonString() }
                return outcome.result.jsonString()
            }
            ctx.setObject(block, forKeyedSubscript: mangled as NSString)
        }

        // JS wrappers (clean names, object in / object out) + injected clock constants.
        var preamble = ""
        for spec in tools {
            let jsName = spec.name.replacingOccurrences(of: ".", with: "_")
            preamble += "function \(jsName)(a){return JSON.parse(__tool_\(jsName)(JSON.stringify(a===undefined?{}:a)));}\n"
        }
        preamble += "var NOW=\(JSONValue.string(box.state.now).jsonString());\n"
        preamble += "var TIMEZONE=\(JSONValue.string(box.state.timezone).jsonString());\n"
        ctx.evaluateScript(preamble)

        // Run the program. A watchdog termination or a top-level throw is a define error.
        ctx.exception = nil
        ctx.evaluateScript(code)
        var defineError: String? = nil
        if let ex = ctx.exception {
            let m = ex.objectForKeyedSubscript("message")
            defineError = (m != nil && !m!.isUndefined && !m!.isNull) ? m!.toString() : ex.toString()
        }

        // Synthesize trace call-lines from the recorded calls so the SAME checker
        // (tool_called counts trace rounds) works unchanged, and compute the corpus
        // revisit summary the same way the tool-calling Runner does.
        var trace: [JSONValue] = [.object([
            "type": .string("meta"), "task": .string(task.id), "tier": .string(task.tier),
            "mode": .string("codeact"), "tool_allowlist": .array(task.toolAllowlist.map { .string($0) }),
        ])]
        var seen: [String] = []; var reads: [JSONValue] = []; var growth: [JSONValue] = []
        for (i, name) in box.calls.enumerated() {
            var o: [String: JSONValue] = ["type": .string("round"), "i": .int(i),
                                          "action": .string("call"), "tool": .string(name)]
            if i < box.callArgs.count { o["args"] = box.callArgs[i] }
            if name == "corpus.read", i < box.callArgs.count, let id = box.callArgs[i]["id"]?.asString {
                let ft = !seen.contains(id); if ft { seen.append(id) }
                reads.append(.object(["round": .int(i), "doc": .string(id), "first_time": .bool(ft)]))
                growth.append(.int(seen.count))
                o["context_docs"] = .array(seen.map { .string($0) })
            }
            trace.append(.object(o))
        }

        let answer = logs.s
        // Observable writable state (what a read tool would return) — reminders, albums, and
        // any notes the program created. This is the honest feedback surface for self-repair.
        let createdNotes = box.state.rows("notes").filter { ($0["id"]?.asString ?? "").hasPrefix("gen_") }
        let snapshot: JSONValue = .object([
            "reminders": .array(box.state.rows("reminders")),
            "albums": .array(box.state.rows("albums")),
            "created_notes": .array(createdNotes),
        ])
        let checks = Checker.evaluate(task: task, state: box.state, answer: answer, trace: trace)
        let ok = !checks.isEmpty && checks.allSatisfy { $0.pass } && defineError == nil
        let revisit: JSONValue = .object([
            "total_reads": .int(reads.count),
            "distinct_docs": .int(seen.count),
            "reread_count": .int(max(0, reads.count - seen.count)),
            "reads": .array(reads),
            "context_growth": .array(growth),
        ])
        let wall = Date().timeIntervalSince(t0) * 1000.0
        trace.append(.object([
            "type": .string("result"), "mode": .string("codeact"), "ok": .bool(ok),
            "define_error": defineError.map { .string($0) } ?? .null,
            "tool_calls": .int(box.calls.count),
            "logs": .string(answer),
            "checks": .array(checks.map { .object(["kind": .string($0.kind), "pass": .bool($0.pass), "detail": .string($0.detail)]) }),
            "corpus_revisits": revisit,
            "wall_ms": .double((wall * 100).rounded() / 100),
        ]))
        return CodeActResult(ok: ok, checks: checks, logs: answer, defineError: defineError,
                             callCount: box.calls.count, wallMs: wall, traceLines: trace, revisit: revisit,
                             stateSnapshot: snapshot)
    }
}
