import Foundation

// AgentPrompt — renders a RoundContext into a single-tool-call prompt for a model-backed
// brain, and parses the model's reply back into a BrainAction. This defines the
// *tool-calling* action protocol (one JSON object per round) that the CodeAct comparison
// (Phase D step 9) measures against. Kept model-agnostic: the CLI's model mode feeds the
// rendered prompt to whatever inference path is available (e.g. the leaderboard
// eval-driver) and hands the completion back to `parse`.
public enum AgentPrompt {

    // Citation scaffold (P2c): does forcing a structured `cited_ids` slot at finish convert
    // 2B's correct-facts-but-no-citation Tier-D answer into a pass? Three rungs isolate
    // "format" from "reasoning" (and from the min-sources read requirement):
    //   .off      — the original free-form {"finish":"…"} protocol (baseline).
    //   .slot     — finish gains a cited_ids[] field the model must populate. Pure format:
    //               does giving it a slot make it write down the ids it already saw?
    //   .readCite — .slot + "you may only cite a document you actually corpus.read". Ties the
    //               citation to the read action, so it also exercises the ≥2-reads gate.
    public enum CiteMode: String { case off = "off", slot = "slot", readCite = "readcite" }

    public static func system(tools: [ToolSpec], cite: CiteMode = .off) -> String {
        // NB: the example uses neutral placeholders, never real corpus ids — the model sees
        // the actual ids in every tool result, so naming them here would leak the answer and
        // invalidate the format-vs-reasoning isolation.
        let finishForm = cite == .off
            ? "  {\"finish\": \"<short summary>\"}              when the task is complete"
            : "  {\"finish\": \"<short summary>\", \"cited_ids\": [\"<id>\", ...]}   when done (cite your sources)"
        var lines = [
            "You are an assistant running on a phone. You accomplish the user's task by calling tools,",
            "ONE per turn. You cannot do anything except call the tools listed below.",
            "",
            "Reply with EXACTLY ONE JSON object and nothing else, in one of these two forms:",
            "  {\"tool\": \"<name>\", \"args\": { ... }}      to call a tool",
            finishForm,
            "",
            "After each tool call you will be shown its JSON result, then asked for the next turn.",
            "Do not invent tools or arguments.",
            "",
            "Finish discipline (important):",
            "- You have a LIMITED number of turns. As soon as you have the information the task",
            "  needs, reply with finish immediately — do not keep searching or reading.",
            "- NEVER call a tool with arguments you already used; its result is already above.",
            "  In particular, never read or search for the same thing twice.",
        ]
        if cite != .off {
            lines += [
                "",
                "Citations (this task requires them):",
                "- In your finish object, `cited_ids` MUST list the `id` values of the corpus",
                "  documents that support the facts in your summary (each id is the \"id\" field",
                "  returned by corpus.search / corpus.read). Cite every source you relied on.",
            ]
            if cite == .readCite {
                lines += [
                    "- You may cite a document id ONLY after reading its full text with corpus.read.",
                    "  A search snippet is NOT enough to cite — read each document you will cite.",
                ]
            }
        }
        lines += ["", "Tools:"]
        for t in tools {
            let ps = t.params.map { "\($0.name)\($0.required ? "" : "?"): \($0.type)" }.joined(separator: ", ")
            lines.append("  \(t.name)(\(ps)) — \(t.summary)")
        }
        return lines.joined(separator: "\n")
    }

    // The user turn for a given round: the task spec + injected clock, then the running
    // transcript of prior tool calls and their results.
    public static func user(ctx: RoundContext) -> String {
        var s = "Task: \(ctx.task.spec)\n"
        if let now = ctx.task.now { s += "Current time: \(now) (\(ctx.task.timezone ?? "UTC"))\n" }
        let left = ctx.task.maxRounds - ctx.round
        s += "Turn \(ctx.round + 1) of \(ctx.task.maxRounds) (\(left) turn\(left == 1 ? "" : "s") left).\n"
        if ctx.transcript.isEmpty {
            s += "\nNo tools called yet. What is your first turn?"
            return s
        }
        s += "\nSo far:\n"
        for (i, e) in ctx.transcript.enumerated() {
            s += "  [\(i)] call \(e.tool)(\(e.args.jsonString())) -> "
            s += e.error.map { "ERROR: \($0)" } ?? e.result.jsonString()
            s += "\n"
        }
        if left <= 2 { s += "\nYou are almost out of turns — if you have what you need, finish NOW." }
        s += "\nWhat is your next turn?"
        return s
    }

    // Warm-mode (held-session) user turn — ONLY the newest tool result, because a stateful
    // brain (kit ChatSession, P3a warm mode) already holds the prior turns in its conversation
    // history + KV. Pairs with `KitModelBrain(warm: true)`: sending just the delta is what lets
    // the prefix cache reuse the system+task+earlier-rounds KV and prefill only this result.
    // The full-transcript `user(ctx:)` above stays the contract for stateless/cold brains (the
    // Mac eval-driver, and KitModelBrain cold mode). Round 0 has no prior result → identical to
    // the full first turn, so the two modes share an identical opening turn.
    public static func incrementalUser(ctx: RoundContext) -> String {
        guard let last = ctx.transcript.last else { return user(ctx: ctx) }
        let left = ctx.task.maxRounds - ctx.round
        var s = "Result of \(last.tool)(\(last.args.jsonString())) -> "
        s += last.error.map { "ERROR: \($0)" } ?? last.result.jsonString()
        s += "\nTurn \(ctx.round + 1) of \(ctx.task.maxRounds) (\(left) turn\(left == 1 ? "" : "s") left)."
        if left <= 2 { s += "\nYou are almost out of turns — if you have what you need, finish NOW." }
        s += "\nWhat is your next turn?"
        return s
    }

    // Parse a completion into an action. Tolerant: finds the first balanced {...} JSON
    // object in the text (models leak prose), and accepts either the call or finish shape.
    public static func parse(_ raw: String) -> BrainAction? {
        guard let obj = firstJSONObject(raw) else { return nil }
        if let finish = obj["finish"]?.asString { return .finish(foldCites(finish, obj, nil)) }
        // Accept the tool shape {tool, args} or {name, arguments}.
        if let tool = (obj["tool"]?.asString ?? obj["name"]?.asString) {
            let args = obj["args"] ?? obj["arguments"] ?? .object([:])
            // Models often express completion as a tool call, e.g. {"tool":"finish","args":
            // {"summary":"…"}}. Treat finish/done as the finish action, not an unknown tool —
            // otherwise a model that wants to stop is forced to keep looping.
            if tool == "finish" || tool == "done" {
                let summary = args["summary"]?.asString ?? args["answer"]?.asString
                    ?? args["text"]?.asString ?? obj["finish"]?.asString ?? ""
                return .finish(foldCites(summary, obj, args))
            }
            return .call(ToolCall(tool: tool, args: args))
        }
        return nil
    }

    // Citation scaffold (P2c): fold a structured `cited_ids` slot into the finish answer so
    // the SAME deterministic Checker (`brief_cites` substring match) scores it — no checker
    // change. Harmless when absent (baseline .off never emits the field). Looks in the finish
    // args first, then the top-level object, so both {"finish":…,"cited_ids":[…]} and
    // {"tool":"finish","args":{"answer":…,"cited_ids":[…]}} work.
    static func foldCites(_ summary: String, _ obj: JSONValue, _ args: JSONValue?) -> String {
        let raw = (args?["cited_ids"]?.asArray) ?? (obj["cited_ids"]?.asArray) ?? []
        let ids = raw.compactMap { $0.asString }.filter { !$0.isEmpty }
        guard !ids.isEmpty else { return summary }
        return summary + " [sources: " + ids.joined(separator: ", ") + "]"
    }

    // Scan for the first brace-balanced JSON object and decode it (ignoring braces inside
    // strings). Returns nil if none parses.
    static func firstJSONObject(_ raw: String) -> JSONValue? {
        let chars = Array(raw)
        var i = 0
        while i < chars.count {
            if chars[i] == "{" {
                var depth = 0, inStr = false, esc = false
                var j = i
                while j < chars.count {
                    let c = chars[j]
                    if inStr {
                        if esc { esc = false }
                        else if c == "\\" { esc = true }
                        else if c == "\"" { inStr = false }
                    } else {
                        if c == "\"" { inStr = true }
                        else if c == "{" { depth += 1 }
                        else if c == "}" {
                            depth -= 1
                            if depth == 0 {
                                let sub = String(chars[i...j])
                                if let v = JSONValue.parse(sub), v.asObject != nil { return v }
                                break
                            }
                        }
                    }
                    j += 1
                }
            }
            i += 1
        }
        return nil
    }
}
