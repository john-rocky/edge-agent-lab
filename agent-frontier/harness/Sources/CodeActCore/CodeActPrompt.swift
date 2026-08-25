import Foundation
import AgentRunCore

// CodeActPrompt — the CodeAct action protocol: instead of one-JSON-tool-call-per-round,
// the model writes ONE JS program that does the whole task (loops/branches in JS, the
// kickoff's thesis). The exposed host functions are AgentRunCore's tools with dots turned
// to underscores. The extractor (JSProbeCore.Prompt.extractJS) pulls the ```js block.
public enum CodeActPrompt {

    // A worked example of the calling convention, for a task NOT in the test set (notes,
    // so no answer leaks to the calendar/photos/corpus test tasks). It demonstrates the
    // *style* the naive runs violated: call the globals directly, guard empty results,
    // loop, object-in/object-out, print the answer with console.log — no window/import/
    // redeclare/invented data. Used only when the few-shot arm is requested.
    public static let fewShotExample = """
    Example (a DIFFERENT task) — task: "Search my notes for the offsite and write one note \
    titled 'Offsite summary' with the date and location." A correct program:
    ```js
    var hits = notes_search({ query: "offsite" });
    if (hits.length === 0) {
      console.log("No offsite notes found.");
    } else {
      var parts = [];
      for (var i = 0; i < hits.length; i++) {
        var note = notes_get({ id: hits[i].id });
        parts.push(note.body);
      }
      notes_create({ title: "Offsite summary", body: parts.join(" ") });
      console.log("Wrote 'Offsite summary' from " + hits.length + " notes.");
    }
    ```
    Notice: the functions are called directly (no import, no `= window`, no redeclaring),
    empty results are guarded, and the answer is printed with console.log.
    """

    public static func system(task: AgentTask, fewShot: Bool = false) -> String {
        let tools = task.toolAllowlist.compactMap { Tools.catalog[$0] }
        var lines = [
            "You are an assistant running on a phone. Accomplish the task by writing ONE",
            "JavaScript program that runs once in a sandbox (JavaScriptCore: no network, no",
            "files, no imports, no async). Write any loops and conditionals yourself.",
            "",
            "You may call these host functions. Each takes a single object argument and",
            "returns a plain JavaScript object (or an array):",
        ]
        for t in tools {
            let jsName = t.name.replacingOccurrences(of: ".", with: "_")
            let ps = t.params.map { "\($0.name)\($0.required ? "" : "?")" }.joined(separator: ", ")
            lines.append("  \(jsName)({ \(ps) }) — \(t.summary)")
        }
        lines.append(contentsOf: [
            "",
            "Also predefined: NOW (an ISO8601 string with offset — the current time) and",
            "TIMEZONE (an IANA name), plus console.log.",
            "",
            "IMPORTANT rules for the program:",
            "- The functions above and NOW/TIMEZONE are ALREADY defined as globals. Call them",
            "  directly. Do NOT import, require, destructure, or redeclare them (no",
            "  `const {…} = …`, no `window`, no `require`). Redeclaring them is an error.",
            "- The ONLY way to get data is to call these functions. Do NOT invent, hardcode,",
            "  or simulate documents, events, photos, or dates — read them via the functions.",
            "- Guard against empty results (a search may return []).",
            "- If the task asks for an answer or brief, print it with console.log — that printed",
            "  text is your answer, so include any required dates, names, and doc ids verbatim.",
            "",
            "Reply with EXACTLY ONE ```js code block and nothing else.",
        ])
        if fewShot { lines.append(contentsOf: ["", fewShotExample]) }
        return lines.joined(separator: "\n")
    }

    public static func user(task: AgentTask) -> String {
        "Task: \(task.spec)\n\nWrite the JavaScript program now, in a single ```js block."
    }

    // The self-repair turn for interactive CodeAct: the model sees the FULL history of prior
    // attempts (each program + grader-free feedback: runtime error, printed output, and the
    // writable device state it produced) and either revises or declares completion. It is
    // NOT told the hidden final_check verdict — only what a real on-device agent could observe.
    //
    // `history` accumulates every prior attempt. Showing all of them (not just the last) +
    // demanding a materially different approach is what makes attempts actually VARY under
    // greedy decoding — it directly attacks the "re-emit the identical broken program"
    // failure, without needing temperature sampling (which would require changing the shared
    // inference engine). Deterministic and reproducible.
    public static func repairUser(task: AgentTask, history: String, attempt: Int) -> String {
        """
        Task: \(task.spec)

        You have already tried \(attempt) approach(es). Here is each program and what happened
        when it ran:

        \(history)
        None of the above fully accomplished the task. Do NOT repeat any program you already
        tried — try a genuinely DIFFERENT approach. Look carefully at the printed output and
        the device state each attempt produced to see what went wrong (e.g. empty results, a
        wrong value, an error). The program runs FRESH each time (state is reset before it
        runs), so write a corrected COMPLETE program. If you are certain the task is already
        fully accomplished, reply with exactly DONE. Otherwise reply with EXACTLY ONE ```js
        code block and nothing else.
        """
    }
}
