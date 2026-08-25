import Foundation
import JSProbeCore

// jsprobe — CLI for the AGENT-P0 JSCore probe.
//
//   jsprobe run     --job <job.json>                    # run one job, print ProbeResult JSON
//   jsprobe grade   --task <task.json> --code <sol.js>  # score a candidate against a task
//   jsprobe selftest --tasks <dir>                      # good->PASS, broken->FAIL discrimination
//   jsprobe extract [--entry <name>] < model_output.txt # print the JS the parser would extract
//
// stdin is accepted where a file arg is omitted (job/code/extract). Deterministic;
// no model, no network — this is the pure scoring half.

func stderr(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
func die(_ s: String) -> Never { stderr(s); exit(2) }
func must<T>(_ v: T?, _ msg: String) -> T { guard let v else { die(msg) }; return v }

func readStdin() -> String {
    let d = FileHandle.standardInput.readDataToEndOfFile()
    return String(data: d, encoding: .utf8) ?? ""
}

func printJSON(_ result: ProbeResult) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.sortedKeys]
    if let d = try? enc.encode(result), let s = String(data: d, encoding: .utf8) { print(s) }
}

// ---- arg parsing -----------------------------------------------------------
struct ArgReader {
    let args: [String]
    func opt(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

let allArgs = Array(CommandLine.arguments.dropFirst())
guard let sub = allArgs.first else {
    die("usage: jsprobe <run|grade|selftest|extract> [options]")
}
let a = ArgReader(args: Array(allArgs.dropFirst()))

switch sub {

// ---- run: a self-contained job -> ProbeResult ------------------------------
case "run":
    // Job JSON: { "entry", "code", "timeout_ms"?, "tests": [{"args":[...], "expect": ...}] }
    let text: String
    if let f = a.opt("--job") { text = must(try? String(contentsOfFile: f, encoding: .utf8), "cannot read \(f)") }
    else { text = readStdin() }
    guard let data = text.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let entry = obj["entry"] as? String,
          let code = obj["code"] as? String,
          let tests = obj["tests"] as? [[String: Any]] else {
        die("bad job JSON (need entry, code, tests[])")
    }
    let timeout = (obj["timeout_ms"] as? Double) ?? 2000
    let argsList: [Any] = tests.map { ($0["args"] as? [Any]) ?? [] }
    let expects: [Any] = tests.map { $0["expect"] ?? NSNull() }
    let result = JSProbe.run(entry: entry, code: code, argsList: argsList,
                             expects: expects, timeoutMs: timeout)
    printJSON(result)
    exit(result.ok ? 0 : 1)

// ---- grade: task + candidate code -> ProbeResult ---------------------------
case "grade":
    guard let taskFile = a.opt("--task") else { die("grade needs --task <task.json>") }
    let task = must(try? TaskSpec.load(URL(fileURLWithPath: taskFile)), "cannot load task \(taskFile)")
    let code: String
    if let f = a.opt("--code") { code = must(try? String(contentsOfFile: f, encoding: .utf8), "cannot read \(f)") }
    else { code = readStdin() }
    let result = JSProbe.run(entry: task.entry, code: code, argsList: task.argsList,
                             expects: task.expects, timeoutMs: task.effectiveTimeoutMs)
    printJSON(result)
    exit(result.ok ? 0 : 1)

// ---- selftest: prove the harness discriminates good from broken -------------
case "selftest":
    guard let dir = a.opt("--tasks") else { die("selftest needs --tasks <dir>") }
    let base = URL(fileURLWithPath: dir)
    let taskURLs = ((try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard !taskURLs.isEmpty else { die("no *.json tasks in \(dir)") }

    var failures = 0
    var checks = 0
    stderr("harness self-test — good solutions must PASS, broken must FAIL\n")
    stderr(String(format: "%-26@ %-8@ %-8@ %@", "task" as NSString, "good" as NSString,
                  "broken" as NSString, "verdict" as NSString))
    stderr(String(repeating: "-", count: 58))

    for url in taskURLs {
        guard let task = try? TaskSpec.load(url) else { stderr("  \(url.lastPathComponent): UNLOADABLE"); failures += 1; continue }
        let goodURL = base.appendingPathComponent("solutions/\(task.id).js")
        let brokenURL = base.appendingPathComponent("broken/\(task.id).js")

        func score(_ u: URL) -> ProbeResult? {
            guard let code = try? String(contentsOf: u, encoding: .utf8) else { return nil }
            return JSProbe.run(entry: task.entry, code: code, argsList: task.argsList,
                               expects: task.expects, timeoutMs: task.effectiveTimeoutMs)
        }

        let good = score(goodURL)
        let broken = score(brokenURL)

        // Expectation: good exists and ok==true; broken exists and ok==false.
        var rowOK = true
        var goodStr = "MISSING", brokenStr = "MISSING"
        if let good {
            checks += 1
            goodStr = good.ok ? "PASS" : "FAIL(\(good.passCount)/\(good.testCount))"
            if !good.ok { rowOK = false }
        } else { rowOK = false }
        if let broken {
            checks += 1
            brokenStr = broken.ok ? "PASS" : "FAIL(\(broken.passCount)/\(broken.testCount))"
            if broken.ok { rowOK = false }   // broken must NOT pass
        } else { rowOK = false }

        if !rowOK { failures += 1 }
        stderr(String(format: "%-26@ %-8@ %-8@ %@", task.id as NSString, goodStr as NSString,
                      brokenStr as NSString, (rowOK ? "ok" : "*** MISMATCH ***") as NSString))
        if let good, !good.ok {
            stderr("      good define_error=\(good.defineError ?? "nil") firstFail=\(good.tests.first(where: { !$0.pass })?.error ?? "?")")
        }
    }
    stderr(String(repeating: "-", count: 58))
    stderr("checks=\(checks)  task-mismatches=\(failures)")
    if failures == 0 { stderr("SELFTEST: PASS ✅") } else { stderr("SELFTEST: FAIL ❌") }
    exit(failures == 0 ? 0 : 1)

// ---- prompt: emit the exact system+user prompt a task hands to the model ----
case "prompt":
    guard let taskFile = a.opt("--task") else { die("prompt needs --task <task.json>") }
    let task = must(try? TaskSpec.load(URL(fileURLWithPath: taskFile)), "cannot load task \(taskFile)")
    if a.args.contains("--json") {
        let obj: [String: Any] = ["system": Prompt.system, "user": Prompt.user(for: task)]
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
           let s = String(data: d, encoding: .utf8) { print(s) }
    } else {
        print("===== SYSTEM =====\n\(Prompt.system)\n\n===== USER =====\n\(Prompt.user(for: task))")
    }
    exit(0)

// ---- extract: what JS would the parser pull from a model completion? --------
case "extract":
    let raw = readStdin()
    let js = Prompt.extractJS(raw, entry: a.opt("--entry"))
    print(js)
    exit(0)

default:
    die("unknown subcommand: \(sub)")
}
