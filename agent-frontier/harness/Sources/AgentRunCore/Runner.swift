import Foundation

// Runner — the agent loop. Brain-agnostic: each round it asks the brain for an action,
// enforces the tool allowlist, executes mock tools against DeviceState, and records a
// trace round. On finish (or max_rounds) it evaluates the task's final_check.
//
// Trace = byproduct ③ (execution-trace format, documented in FORMATS.md §3). One JSONL
// file per run: a meta line, one line per round (action + args + result + state digest +
// corpus context), and a result line (ok + per-assertion checks + corpus-revisit summary).
// The corpus-revisit summary is the seed for the later prefix-cache comparison: it records
// which corpus docs are re-read across rounds (the reused KV prefix).

public struct CheckResult: Codable {
    public let kind: String
    public let pass: Bool
    public let detail: String
}

public struct RunResult {
    public let taskId: String
    public let tier: String
    public let brain: String
    public let ok: Bool
    public let rounds: Int
    public let checks: [CheckResult]
    public let finalAnswer: String
    public let wallMs: Double
    public let traceLines: [JSONValue]   // meta + round* + result, ready to write as JSONL
    public let revisit: JSONValue        // corpus-revisit summary (also embedded in result line)
}

public enum Runner {

    public static func run(task: AgentTask, brain: inout Brain) -> RunResult {
        let t0 = Date()
        var state = DeviceState(task: task)
        var transcript: [TranscriptEntry] = []
        let tools = task.toolAllowlist.compactMap { Tools.catalog[$0] }

        var trace: [JSONValue] = []
        trace.append(.object([
            "type": .string("meta"),
            "task": .string(task.id),
            "tier": .string(task.tier),
            "brain": .string(brain.label),
            "spec": .string(task.spec),
            "now": .string(state.now),
            "timezone": .string(state.timezone),
            "max_rounds": .int(task.maxRounds),
            "tool_allowlist": .array(task.toolAllowlist.map { .string($0) }),
        ]))

        // Corpus-revisit tracking: the ordered list of corpus.read events and the growing
        // set of docs "in context" (the prefix a KV cache would keep warm across rounds).
        var readEvents: [JSONValue] = []
        var seenDocs: [String] = []
        var contextGrowth: [JSONValue] = []
        var toolCallCounts: [String: Int] = [:]

        var finalAnswer = ""
        var usedRounds = 0

        for round in 0..<task.maxRounds {
            usedRounds = round + 1
            let ctx = RoundContext(task: task, round: round, state: state, transcript: transcript, tools: tools)
            let action: BrainAction
            do { action = try brain.next(ctx) }
            catch {
                trace.append(.object(["type": .string("round"), "i": .int(round),
                                      "action": .string("error"), "error": .string("brain: \(error)")]))
                break
            }

            switch action {
            case .finish(let ans):
                finalAnswer = ans
                trace.append(.object(["type": .string("round"), "i": .int(round),
                                      "action": .string("finish"),
                                      "answer": .string(ans)]))
                let checks = Checker.evaluate(task: task, state: state, answer: ans, trace: trace)
                return finalize(task, brain, state, checks, ans, usedRounds, t0, &trace,
                                readEvents, seenDocs, contextGrowth)

            case .call(let tc):
                let rt0 = Date()
                toolCallCounts[tc.tool, default: 0] += 1
                var roundObj: [String: JSONValue] = [
                    "type": .string("round"), "i": .int(round),
                    "action": .string("call"), "tool": .string(tc.tool), "args": tc.args,
                ]
                if !task.toolAllowlist.contains(tc.tool) {
                    roundObj["error"] = .string("tool '\(tc.tool)' not in allowlist")
                    transcript.append(TranscriptEntry(tool: tc.tool, args: tc.args, result: .null,
                                                      error: "not in allowlist"))
                    trace.append(.object(roundObj))
                    continue
                }
                guard let spec = Tools.catalog[tc.tool] else {
                    roundObj["error"] = .string("unknown tool '\(tc.tool)'")
                    transcript.append(TranscriptEntry(tool: tc.tool, args: tc.args, result: .null, error: "unknown tool"))
                    trace.append(.object(roundObj))
                    continue
                }
                let outcome = spec.run(tc.args, &state)
                // Repeat nudge: if this exact (tool,args) was already called, the model is
                // looping (the 2B Tier-D reread failure). Surface a warning in the result it
                // sees next turn so it stops re-reading and finishes.
                let sig = tc.tool + "|" + tc.args.jsonString()
                let isDup = transcript.contains { $0.tool + "|" + $0.args.jsonString() == sig }
                let shownResult: JSONValue = isDup
                    ? .object(["repeat_warning": .string("You already made this exact call earlier — reuse that result and finish if you have enough."),
                               "result": outcome.result])
                    : outcome.result
                roundObj["result"] = shownResult
                if isDup { roundObj["repeat"] = .bool(true) }
                if let e = outcome.error { roundObj["error"] = .string(e) }
                roundObj["state"] = state.digest()

                // Record corpus revisits when a document is read.
                if tc.tool == "corpus.read", outcome.error == nil, let id = tc.args["id"]?.asString {
                    let firstTime = !seenDocs.contains(id)
                    if firstTime { seenDocs.append(id) }
                    readEvents.append(.object(["round": .int(round), "doc": .string(id), "first_time": .bool(firstTime)]))
                    contextGrowth.append(.int(seenDocs.count))
                    roundObj["context_docs"] = .array(seenDocs.map { .string($0) })
                }

                transcript.append(TranscriptEntry(tool: tc.tool, args: tc.args, result: shownResult, error: outcome.error))
                trace.append(.object(roundObj))
            }
        }

        // Fell out of the loop without finishing (hit max_rounds).
        let checks = Checker.evaluate(task: task, state: state, answer: finalAnswer, trace: trace)
        return finalize(task, brain, state, checks, finalAnswer, usedRounds, t0, &trace,
                        readEvents, seenDocs, contextGrowth)
    }

    private static func finalize(_ task: AgentTask, _ brain: Brain, _ state: DeviceState,
                                 _ checks: [CheckResult], _ answer: String, _ rounds: Int, _ t0: Date,
                                 _ trace: inout [JSONValue],
                                 _ readEvents: [JSONValue], _ seenDocs: [String],
                                 _ contextGrowth: [JSONValue]) -> RunResult {
        let ok = !checks.isEmpty && checks.allSatisfy { $0.pass }
        let revisit: JSONValue = .object([
            "total_reads": .int(readEvents.count),
            "distinct_docs": .int(seenDocs.count),
            "reread_count": .int(max(0, readEvents.count - seenDocs.count)),
            "reads": .array(readEvents),
            "context_growth": .array(contextGrowth),
        ])
        let wall = Date().timeIntervalSince(t0) * 1000.0
        let checkVals: [JSONValue] = checks.map {
            .object(["kind": .string($0.kind), "pass": .bool($0.pass), "detail": .string($0.detail)])
        }
        trace.append(.object([
            "type": .string("result"),
            "ok": .bool(ok),
            "rounds": .int(rounds),
            "final_answer": .string(answer),
            "checks": .array(checkVals),
            "corpus_revisits": revisit,
            "wall_ms": .double((wall * 100).rounded() / 100),
        ]))
        return RunResult(taskId: task.id, tier: task.tier, brain: brain.label, ok: ok, rounds: rounds,
                         checks: checks, finalAnswer: answer, wallMs: wall, traceLines: trace, revisit: revisit)
    }
}
