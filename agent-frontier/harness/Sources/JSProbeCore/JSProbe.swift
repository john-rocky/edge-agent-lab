import Foundation
import JavaScriptCore
import CJSWatchdog

// JSProbe — run a candidate JS solution against a task's test vectors inside a
// sandboxed JSContext, and decide pass@1.
//
// Sandbox properties:
//   * A dedicated JSVirtualMachine per candidate (no shared global state).
//   * A watchdog execution-time limit (JSContextGroupSetExecutionTimeLimit) so an
//     infinite loop in generated code terminates instead of hanging the harness.
//   * Only `console.log/info/warn/error` are bridged (captured to a string). No
//     network, no filesystem, no timers — a small model can only compute.
//
// Scoring: the candidate is expected to DEFINE a function named `entry`. For each
// test vector we call entry(...args) and deep-equal the result against `expect`.
// pass@1 == (define succeeded) AND (every test vector passed).

public struct TestOutcome: Codable {
    public var pass: Bool
    public var error: String?
    public var got: String?   // JSON.stringify of the actual return value (nil if it threw)
}

public struct ProbeResult: Codable {
    public var ok: Bool                 // pass@1: all tests passed and no define error
    public var defineError: String?     // syntax error / top-level throw while defining
    public var passCount: Int
    public var testCount: Int
    public var tests: [TestOutcome]
    public var logs: String             // captured console output
    public var wallMs: Double

    enum CodingKeys: String, CodingKey {
        case ok, defineError = "define_error", passCount = "pass_count",
             testCount = "test_count", tests, logs, wallMs = "wall_ms"
    }
}

public enum JSProbe {

    // Injected once per context: a deep, order-independent equality with a small
    // float epsilon, plus a safe JSON stringifier used to report actual values.
    private static let helpers = """
    function __deepEqual(a, b) {
      if (a === b) return true;
      if (typeof a === 'number' && typeof b === 'number') {
        if (isNaN(a) && isNaN(b)) return true;
        return Math.abs(a - b) <= 1e-6 * Math.max(1, Math.abs(a), Math.abs(b));
      }
      if (a === null || b === null || a === undefined || b === undefined) return a === b;
      var aArr = Array.isArray(a), bArr = Array.isArray(b);
      if (aArr || bArr) {
        if (!aArr || !bArr || a.length !== b.length) return false;
        for (var i = 0; i < a.length; i++) if (!__deepEqual(a[i], b[i])) return false;
        return true;
      }
      if (typeof a === 'object' && typeof b === 'object') {
        var ka = Object.keys(a).sort(), kb = Object.keys(b).sort();
        if (ka.length !== kb.length) return false;
        for (var j = 0; j < ka.length; j++) {
          if (ka[j] !== kb[j]) return false;
          if (!__deepEqual(a[ka[j]], b[kb[j]])) return false;
        }
        return true;
      }
      return false;
    }
    function __safeStr(x) { try { return JSON.stringify(x); } catch (e) { return String(x); } }
    """

    /// Run one candidate against a task.
    /// - Parameters:
    ///   - entry: the function name the candidate must define.
    ///   - code: the candidate JS source.
    ///   - argsList: per-test argument arrays (each element is the arguments list for one call).
    ///   - expects: per-test expected return values (parallel to argsList).
    ///   - timeoutMs: watchdog limit per script evaluation.
    public static func run(entry: String,
                           code: String,
                           argsList: [Any],
                           expects: [Any],
                           timeoutMs: Double) -> ProbeResult {
        let t0 = Date()
        let recorder = Recorder()
        let vm = JSVirtualMachine()!
        let ctx = JSContext(virtualMachine: vm)!

        // Watchdog: terminate any single evaluation that runs longer than the limit.
        let group = JSContextGetGroup(ctx.jsGlobalContextRef)
        cjs_set_time_limit(group, timeoutMs / 1000.0)

        // Bridge console.* into a captured buffer; no other host capabilities.
        let sink: @convention(block) (JSValue?) -> Void = { v in
            recorder.logs += (v?.toString() ?? "") + "\n"
        }
        ctx.setObject(sink, forKeyedSubscript: "__logSink" as NSString)
        _ = eval(ctx, recorder, """
        var console = {
          log:   function() { __logSink(Array.prototype.slice.call(arguments).join(' ')); },
          info:  function() { __logSink(Array.prototype.slice.call(arguments).join(' ')); },
          warn:  function() { __logSink(Array.prototype.slice.call(arguments).join(' ')); },
          error: function() { __logSink(Array.prototype.slice.call(arguments).join(' ')); }
        };
        """)
        _ = eval(ctx, recorder, helpers)

        // Define the candidate. A syntax error or top-level throw is a define error.
        recorder.lastException = nil
        _ = eval(ctx, recorder, code)
        let defineError = recorder.lastException

        var outcomes: [TestOutcome] = []
        for (i, args) in argsList.enumerated() {
            let expect = i < expects.count ? expects[i] : NSNull()
            outcomes.append(runOne(ctx, recorder, entry: entry, args: args, expect: expect))
        }

        let passCount = outcomes.filter { $0.pass }.count
        let ok = defineError == nil && passCount == outcomes.count && !outcomes.isEmpty
        return ProbeResult(
            ok: ok,
            defineError: defineError,
            passCount: passCount,
            testCount: outcomes.count,
            tests: outcomes,
            logs: recorder.logs,
            wallMs: Date().timeIntervalSince(t0) * 1000.0
        )
    }

    private static func runOne(_ ctx: JSContext, _ rec: Recorder,
                               entry: String, args: Any, expect: Any) -> TestOutcome {
        // Marshal args/expect through JSON.parse so JS types (boolean/null/number)
        // are exact — avoids NSNumber<->boolean bridging ambiguity from setObject.
        guard let argsJSON = jsonString(args), let expectJSON = jsonString(expect) else {
            return TestOutcome(pass: false, error: "cannot encode test vector as JSON", got: nil)
        }
        ctx.setObject(argsJSON as NSString, forKeyedSubscript: "__argsJSON" as NSString)
        ctx.setObject(expectJSON as NSString, forKeyedSubscript: "__expectJSON" as NSString)
        rec.lastException = nil
        _ = eval(ctx, rec, "var __args = JSON.parse(__argsJSON); var __expect = JSON.parse(__expectJSON);")

        // The try/catch reports ordinary errors as data. A watchdog termination is
        // uncatchable and surfaces as a nil return + set exception -> "timeout".
        let wrapper = """
        (function () {
          try {
            if (typeof \(entry) !== 'function') return { ok: false, got: null, err: 'no function named \(entry)' };
            var r = \(entry).apply(null, __args);
            return { ok: __deepEqual(r, __expect), got: __safeStr(r), err: null };
          } catch (e) { return { ok: false, got: null, err: String((e && e.message) || e) }; }
        })()
        """
        rec.lastException = nil
        guard let res = eval(ctx, rec, wrapper), res.isObject else {
            return TestOutcome(pass: false, error: rec.lastException ?? "terminated (timeout)", got: nil)
        }
        let ok = res.objectForKeyedSubscript("ok")?.toBool() ?? false
        let gotV = res.objectForKeyedSubscript("got")
        let errV = res.objectForKeyedSubscript("err")
        let got = (gotV?.isNull ?? true) ? nil : gotV?.toString()
        let err = (errV?.isNull ?? true) ? nil : errV?.toString()
        return TestOutcome(pass: ok, error: ok ? nil : (err ?? "mismatch"), got: got)
    }

    /// Evaluate a script, capturing any thrown exception into the recorder and
    /// clearing it from the context so it does not cascade into the next eval.
    @discardableResult
    private static func eval(_ ctx: JSContext, _ rec: Recorder, _ script: String) -> JSValue? {
        ctx.exception = nil
        let v = ctx.evaluateScript(script)
        if let ex = ctx.exception {
            // Error objects carry a `.message`; a watchdog termination surfaces as a
            // bare string ("JavaScript execution terminated."), which has no message
            // property — fall back to the exception's own string form in that case.
            let msgVal = ex.objectForKeyedSubscript("message")
            let msg = (msgVal != nil && !msgVal!.isUndefined && !msgVal!.isNull) ? msgVal!.toString() : nil
            rec.lastException = (msg?.isEmpty == false ? msg : ex.toString()) ?? "unknown error"
            ctx.exception = nil
            return nil
        }
        return v
    }

    private static func jsonString(_ obj: Any) -> String? {
        guard JSONSerialization.isValidJSONObject([obj]) || obj is NSNull else {
            // Allow top-level scalars by wrapping/unwrapping.
            if let d = try? JSONSerialization.data(withJSONObject: [obj]),
               let s = String(data: d, encoding: .utf8) {
                return String(s.dropFirst().dropLast()) // strip the wrapping [ ]
            }
            return nil
        }
        guard let d = try? JSONSerialization.data(withJSONObject: [obj]),
              let s = String(data: d, encoding: .utf8) else { return nil }
        return String(s.dropFirst().dropLast())
    }

    private final class Recorder {
        var logs = ""
        var lastException: String?
    }
}
