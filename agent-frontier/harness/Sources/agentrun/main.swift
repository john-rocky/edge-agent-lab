import Foundation
import AgentRunCore
import CodeActCore
import JSProbeCore   // reuse the P0 ```js extractor for the CodeAct model arm

// agentrun — CLI for the Tier-A / Tier-D agent probe (the tool-calling rung of the ladder).
//
//   agentrun selftest --tasks <dir>                  # MockBrain PASSes, NullBrain FAILs (checker discriminates)
//   agentrun run --task <f> [--brain mock|null|model] [--trace out.jsonl]
//   agentrun manifest [--task <f> | --all]           # emit the JS-bridge manifest (byproduct ②)
//   agentrun prompt --task <f>                        # emit the tool-calling system+user prompt
//
// mock/null are CPU-only and deterministic (the self-test path). `--brain model` shells
// out to the leaderboard eval-driver once per round — GPU-bound, so it must run under the
// shared _GPU_LOCK (the Phase D driver enforces that, mirroring run_phaseB.sh).

func stderr(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
func die(_ s: String) -> Never { stderr(s); exit(2) }

struct ArgReader {
    let args: [String]
    func opt(_ n: String) -> String? {
        guard let i = args.firstIndex(of: n), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    func has(_ n: String) -> Bool { args.contains(n) }
}

// A brain that does nothing (finishes immediately). Used by selftest as the negative
// control: it proves final_check actually requires the work to be done, not that the
// check trivially passes.
struct NullBrain: Brain {
    let label = "null"
    func next(_ ctx: RoundContext) throws -> BrainAction { .finish("(did nothing)") }
}

// Model-backed brain: renders the round into a prompt, asks the model (via eval-driver)
// for one tool call, parses it. One model process per round (eval-driver loads once per
// invocation) — fine for a smoke test; a warm multi-turn session is the deferred
// heavy-wiring job. GPU-bound: run only under _GPU_LOCK.
struct ShellModelBrain: Brain {
    let label: String
    let evalDriver: String
    let bundle: String
    let maxTokens: Int
    let workDir: String
    let cite: AgentPrompt.CiteMode   // P2c citation scaffold: off | slot | readcite

    func next(_ ctx: RoundContext) throws -> BrainAction {
        let sys = AgentPrompt.system(tools: ctx.tools, cite: cite)
        let user = AgentPrompt.user(ctx: ctx)
        let dataPath = "\(workDir)/round_\(ctx.round)_in.jsonl"
        let outPath = "\(workDir)/round_\(ctx.round)_out.jsonl"
        let line = JSONValue.object(["key": .string("r\(ctx.round)"), "prompt": .string(user)]).jsonString()
        try line.write(toFile: dataPath, atomically: true, encoding: .utf8)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: evalDriver)
        p.arguments = ["--bundle", bundle, "--data", dataPath, "--out", outPath,
                       "--system", sys, "--prompt-field", "prompt", "--key-field", "key",
                       "--max-tokens", String(maxTokens), "--engine", "pipelined", "--limit", "1"]
        var env = ProcessInfo.processInfo.environment
        env["COREAI_CHUNK_THRESHOLD"] = "1"
        p.environment = env
        p.standardOutput = FileHandle.nullDevice
        // Let eval-driver's stderr progress flow to ours so a smoke run is observable.
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let out = try? String(contentsOfFile: outPath, encoding: .utf8),
              let firstLine = out.split(separator: "\n").first,
              let obj = JSONValue.parse(String(firstLine)),
              let answer = obj["answer"]?.asString else {
            return .finish("(model call failed at round \(ctx.round))")
        }
        return AgentPrompt.parse(answer) ?? .finish("(unparseable model reply: \(answer.prefix(80)))")
    }
}

func loadTasks(_ dir: String) -> [AgentTask] {
    let base = URL(fileURLWithPath: dir)
    let urls = ((try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    return urls.compactMap { try? AgentTask.load($0) }
}

func writeTrace(_ lines: [JSONValue], to path: String) {
    let text = lines.map { $0.jsonString() }.joined(separator: "\n") + "\n"
    try? text.write(toFile: path, atomically: true, encoding: .utf8)
}

// One-shot model call for the CodeAct arm: render one prompt, run eval-driver ONCE, return
// the completion. GPU-bound (the driver gates it under _GPU_LOCK), same as ShellModelBrain.
func oneShotModel(evalDriver: String, bundle: String, system: String, user: String,
                  maxTokens: Int, workDir: String) -> String? {
    try? FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)
    let dataPath = "\(workDir)/codeact_in.jsonl", outPath = "\(workDir)/codeact_out.jsonl"
    let line = JSONValue.object(["key": .string("c0"), "prompt": .string(user)]).jsonString()
    try? line.write(toFile: dataPath, atomically: true, encoding: .utf8)
    let p = Process()
    p.executableURL = URL(fileURLWithPath: evalDriver)
    p.arguments = ["--bundle", bundle, "--data", dataPath, "--out", outPath,
                   "--system", system, "--prompt-field", "prompt", "--key-field", "key",
                   "--max-tokens", String(maxTokens), "--engine", "pipelined", "--limit", "1"]
    var env = ProcessInfo.processInfo.environment
    env["COREAI_CHUNK_THRESHOLD"] = "1"
    p.environment = env
    p.standardOutput = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    p.waitUntilExit()
    guard p.terminationStatus == 0,
          let out = try? String(contentsOfFile: outPath, encoding: .utf8),
          let first = out.split(separator: "\n").first,
          let obj = JSONValue.parse(String(first)) else { return nil }
    return obj["answer"]?.asString
}

func codeActResultJSON(_ task: AgentTask, _ r: CodeActResult) -> JSONValue {
    .object([
        "task": .string(task.id), "tier": .string(task.tier), "mode": .string("codeact"),
        "ok": .bool(r.ok), "tool_calls": .int(r.callCount),
        "define_error": r.defineError.map { .string($0) } ?? .null,
        "checks": .array(r.checks.map { .object(["kind": .string($0.kind), "pass": .bool($0.pass), "detail": .string($0.detail)]) }),
        "corpus_revisits": r.revisit,
    ])
}

// ---------------------------------------------------------------------------
let all = Array(CommandLine.arguments.dropFirst())
guard let sub = all.first else { die("usage: agentrun <selftest|run|manifest|prompt> [options]") }
let a = ArgReader(args: Array(all.dropFirst()))

switch sub {

// ---- selftest: MockBrain must PASS every task; NullBrain must FAIL every task -------
case "selftest":
    guard let dir = a.opt("--tasks") else { die("selftest needs --tasks <dir>") }
    let tasks = loadTasks(dir)
    guard !tasks.isEmpty else { die("no *.json tasks in \(dir)") }
    stderr("agent harness self-test — mock_solution must PASS, null (do-nothing) must FAIL\n")
    stderr(String(format: "%-30@ %-6@ %-6@ %-8@ %@", "task" as NSString, "tier" as NSString,
                  "mock" as NSString, "null" as NSString, "verdict" as NSString))
    stderr(String(repeating: "-", count: 72))
    var mismatches = 0, checks = 0
    for task in tasks {
        var mock: Brain = MockBrain(task)
        var null: Brain = NullBrain()
        let rMock = Runner.run(task: task, brain: &mock)
        let rNull = Runner.run(task: task, brain: &null)
        checks += 2
        let rowOK = rMock.ok && !rNull.ok
        if !rowOK { mismatches += 1 }
        let mockStr = rMock.ok ? "PASS" : "FAIL"
        let nullStr = rNull.ok ? "PASS" : "FAIL"
        stderr(String(format: "%-30@ %-6@ %-6@ %-8@ %@", task.id as NSString, task.tier as NSString,
                      mockStr as NSString, nullStr as NSString,
                      (rowOK ? "ok" : "*** MISMATCH ***") as NSString))
        if !rMock.ok {
            for c in rMock.checks where !c.pass { stderr("      mock fail [\(c.kind)]: \(c.detail)") }
        }
    }
    stderr(String(repeating: "-", count: 72))
    stderr("checks=\(checks)  task-mismatches=\(mismatches)")
    stderr(mismatches == 0 ? "AGENT SELFTEST: PASS ✅" : "AGENT SELFTEST: FAIL ❌")
    exit(mismatches == 0 ? 0 : 1)

// ---- codeact-selftest: reference JS program PASSes; empty program FAILs --------------
case "codeact-selftest":
    guard let dir = a.opt("--tasks") else { die("codeact-selftest needs --tasks <dir>") }
    let refDir = a.opt("--ref-dir") ?? "codeact"
    let tasks = loadTasks(dir).filter { FileManager.default.fileExists(atPath: "\(refDir)/\($0.id).js") }
    guard !tasks.isEmpty else { die("no tasks in \(dir) have a reference program in \(refDir)/") }
    stderr("CodeAct harness self-test — reference program must PASS, empty program must FAIL\n")
    stderr(String(format: "%-30@ %-6@ %-6@ %@", "task" as NSString, "ref" as NSString, "empty" as NSString, "verdict" as NSString))
    stderr(String(repeating: "-", count: 60))
    var mismatches = 0, checks = 0
    for task in tasks {
        let refCode = (try? String(contentsOfFile: "\(refDir)/\(task.id).js", encoding: .utf8)) ?? ""
        let rRef = CodeAct.run(task: task, code: refCode)
        let rEmpty = CodeAct.run(task: task, code: "// nothing")
        checks += 2
        let rowOK = rRef.ok && !rEmpty.ok
        if !rowOK { mismatches += 1 }
        stderr(String(format: "%-30@ %-6@ %-6@ %@", task.id as NSString, (rRef.ok ? "PASS" : "FAIL") as NSString,
                      (rEmpty.ok ? "PASS" : "FAIL") as NSString, (rowOK ? "ok" : "*** MISMATCH ***") as NSString))
        if !rRef.ok {
            if let de = rRef.defineError { stderr("      ref define_error: \(de)") }
            for c in rRef.checks where !c.pass { stderr("      ref fail [\(c.kind)]: \(c.detail)") }
        }
    }
    stderr(String(repeating: "-", count: 60))
    stderr("checks=\(checks)  task-mismatches=\(mismatches)")
    stderr(mismatches == 0 ? "CODEACT SELFTEST: PASS ✅" : "CODEACT SELFTEST: FAIL ❌")
    exit(mismatches == 0 ? 0 : 1)

// ---- run: one task, one brain -> result JSON (+ optional trace) ---------------------
case "run":
    guard let taskFile = a.opt("--task") else { die("run needs --task <file>") }
    let task = (try? AgentTask.load(URL(fileURLWithPath: taskFile))) ?? { die("cannot load \(taskFile)") }()

    // ---- Interactive CodeAct: write program -> run -> observe -> repair (up to K) ------
    // Isolates the FEEDBACK variable: starts from the few-shot baseline (clean API usage)
    // and adds a grader-free self-repair loop. Breaks on the first grader-passing attempt
    // (for scoring/efficiency only — the model is never told the verdict) or when the model
    // replies DONE or attempts run out.
    if a.opt("--mode") == "codeact-interactive" {
        guard let ed = a.opt("--eval-driver"), let bundle = a.opt("--bundle") else {
            die("--mode codeact-interactive needs --eval-driver <bin> --bundle <dir>")
        }
        let maxAttempts = Int(a.opt("--max-attempts") ?? "4") ?? 4
        let work = a.opt("--work") ?? NSTemporaryDirectory() + "codeactI_\(task.id)"
        let sys = CodeActPrompt.system(task: task, fewShot: true)
        let maxTok = Int(a.opt("--max-tokens") ?? "700") ?? 700
        var history = "", attempts = 0, passedAt = -1
        var log: [JSONValue] = []
        for k in 0..<maxAttempts {
            attempts = k + 1
            let user = k == 0 ? CodeActPrompt.user(task: task)
                              : CodeActPrompt.repairUser(task: task, history: history, attempt: k)
            guard let answer = oneShotModel(evalDriver: ed, bundle: bundle, system: sys, user: user,
                                            maxTokens: maxTok, workDir: "\(work)/a\(k)") else { break }
            // Model declares completion?
            let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "DONE" || (trimmed.uppercased().hasPrefix("DONE") && !trimmed.contains("```")) {
                log.append(.object(["attempt": .int(k), "action": .string("declared_done")]))
                break
            }
            let code = Prompt.extractJS(answer)
            let r = CodeAct.run(task: task, code: code)
            history += "--- Attempt #\(k) program:\n```js\n\(code)\n```\nResult of attempt #\(k):\n\(r.feedback())\n"
            log.append(.object(["attempt": .int(k), "ok": .bool(r.ok), "tool_calls": .int(r.callCount),
                                "define_error": r.defineError.map { .string($0) } ?? .null,
                                "state": r.stateSnapshot]))
            try? code.write(toFile: "\(work)/prog_a\(k).js", atomically: true, encoding: .utf8)
            if r.ok { passedAt = k; break }   // reached a passing program (grader; not shown to model)
        }
        let out = JSONValue.object([
            "task": .string(task.id), "tier": .string(task.tier), "mode": .string("codeact-interactive"),
            "attempts": .int(attempts), "passed": .bool(passedAt >= 0),
            "passed_at_attempt": .int(passedAt), "log": .array(log),
        ])
        if let tp = a.opt("--trace") { writeTrace(log, to: tp) }
        print(out.jsonString())
        exit(passedAt >= 0 ? 0 : 1)
    }

    // ---- CodeAct arm: run ONE JS program (reference file or one model call) ----------
    if a.opt("--mode") == "codeact" {
        let brainName = a.opt("--brain") ?? "ref"
        let code: String
        switch brainName {
        case "ref":
            let dir = a.opt("--ref-dir") ?? "codeact"
            let path = "\(dir)/\(task.id).js"
            code = (try? String(contentsOfFile: path, encoding: .utf8)) ?? { die("no reference program \(path)") }()
        case "model":
            guard let ed = a.opt("--eval-driver"), let bundle = a.opt("--bundle") else {
                die("--mode codeact --brain model needs --eval-driver <bin> --bundle <dir>")
            }
            let work = a.opt("--work") ?? NSTemporaryDirectory() + "codeact_\(task.id)"
            let sys = CodeActPrompt.system(task: task, fewShot: a.has("--few-shot"))
            let usr = CodeActPrompt.user(task: task)
            guard let answer = oneShotModel(evalDriver: ed, bundle: bundle, system: sys, user: usr,
                                            maxTokens: Int(a.opt("--max-tokens") ?? "700") ?? 700, workDir: work) else {
                die("model call failed")
            }
            code = Prompt.extractJS(answer)   // reuse the P0 ```js extractor
            if let cp = a.opt("--save-code") { try? code.write(toFile: cp, atomically: true, encoding: .utf8) }
        default: die("codeact brain must be 'ref' or 'model'")
        }
        let r = CodeAct.run(task: task, code: code)
        if let tp = a.opt("--trace") { writeTrace(r.traceLines, to: tp); stderr("trace -> \(tp)") }
        print(codeActResultJSON(task, r).jsonString())
        exit(r.ok ? 0 : 1)
    }

    let brainName = a.opt("--brain") ?? "mock"
    var brain: Brain
    switch brainName {
    case "mock": brain = MockBrain(task)
    case "null": brain = NullBrain()
    case "model":
        guard let ed = a.opt("--eval-driver"), let bundle = a.opt("--bundle") else {
            die("--brain model needs --eval-driver <bin> --bundle <dir>")
        }
        let work = a.opt("--work") ?? NSTemporaryDirectory() + "agentrun_\(task.id)"
        try? FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
        let cite = AgentPrompt.CiteMode(rawValue: a.opt("--cite") ?? "off") ?? .off
        brain = ShellModelBrain(label: "model:\(a.opt("--label") ?? "qwen")", evalDriver: ed,
                                bundle: bundle, maxTokens: Int(a.opt("--max-tokens") ?? "512") ?? 512,
                                workDir: work, cite: cite)
    default: die("unknown brain '\(brainName)'")
    }
    let r = Runner.run(task: task, brain: &brain)
    if let tp = a.opt("--trace") { writeTrace(r.traceLines, to: tp); stderr("trace -> \(tp)") }
    let summary = JSONValue.object([
        "task": .string(r.taskId), "tier": .string(r.tier), "brain": .string(r.brain),
        "ok": .bool(r.ok), "rounds": .int(r.rounds), "final_answer": .string(r.finalAnswer),
        "checks": .array(r.checks.map { .object(["kind": .string($0.kind), "pass": .bool($0.pass), "detail": .string($0.detail)]) }),
        "corpus_revisits": r.revisit,
    ])
    print(summary.jsonString())
    exit(r.ok ? 0 : 1)

// ---- manifest: the JS-bridge capability/permission manifest (byproduct ②) -----------
case "manifest":
    let names: [String]
    if let taskFile = a.opt("--task") {
        let task = (try? AgentTask.load(URL(fileURLWithPath: taskFile))) ?? { die("cannot load \(taskFile)") }()
        names = task.toolAllowlist
    } else {
        names = Tools.all.map { $0.name }   // --all (default): the whole catalog
    }
    print(Manifest.build(toolNames: names).jsonString(pretty: true))
    exit(0)

// ---- prompt: emit the tool-calling system + first-round user prompt -----------------
case "prompt":
    guard let taskFile = a.opt("--task") else { die("prompt needs --task <file>") }
    let task = (try? AgentTask.load(URL(fileURLWithPath: taskFile))) ?? { die("cannot load \(taskFile)") }()
    let tools = task.toolAllowlist.compactMap { Tools.catalog[$0] }
    let cite = AgentPrompt.CiteMode(rawValue: a.opt("--cite") ?? "off") ?? .off   // P2c: inspect scaffold
    let ctx = RoundContext(task: task, round: 0, state: DeviceState(task: task), transcript: [], tools: tools)
    print("===== SYSTEM (cite=\(cite.rawValue)) =====\n\(AgentPrompt.system(tools: tools, cite: cite))\n\n===== USER (round 0) =====\n\(AgentPrompt.user(ctx: ctx))")
    exit(0)

// ---- parsecheck: parse a raw model reply into an action (offline scaffold verification) --
// Confirms the citation scaffold's cited_ids slot folds into the finish answer the Checker
// sees, without spending GPU. `agentrun parsecheck --raw '<json>'`.
case "parsecheck":
    guard let raw = a.opt("--raw") else { die("parsecheck needs --raw '<model reply>'") }
    switch AgentPrompt.parse(raw) {
    case .finish(let s): print("FINISH -> \(s)")
    case .call(let tc): print("CALL   -> \(tc.tool)(\(tc.args.jsonString()))")
    case nil:           print("UNPARSEABLE")
    }
    exit(0)

default:
    die("unknown subcommand: \(sub)")
}
