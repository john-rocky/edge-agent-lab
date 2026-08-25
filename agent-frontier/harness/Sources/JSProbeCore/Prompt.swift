import Foundation

// Prompt building + code extraction — the model-facing half of the harness.
//
// Small models are steered hard toward "emit exactly one ```js block that defines
// the requested function, nothing else". The extractor is deliberately forgiving
// because small models leak prose, repeat the block, or forget the language tag.

public enum Prompt {

    /// The system instruction. Kept short: small models follow short rules better.
    public static let system = """
    You are a JavaScript coding engine running on a phone. You write small, correct \
    JavaScript functions that run in a sandbox (JavaScriptCore): no network, no files, \
    no imports, no async. Only pure computation and console.log are available.

    Rules:
    - Reply with exactly ONE code block: ```js ... ```
    - Define the requested function with the exact name and signature. Do not call it.
    - No explanation before or after the code block.
    - Use only standard JavaScript (ES5/ES6). Do not require or import anything.
    """

    /// The per-task user message.
    public static func user(for task: TaskSpec) -> String {
        """
        \(task.prompt)

        Signature: \(task.signature)

        Return only the function definition in a single ```js code block.
        """
    }

    /// Extract JS from a model completion.
    /// Priority: first ```js (or ```javascript) fenced block; then any ``` block;
    /// then, if a bare `function <entry>` appears, take from there to the end;
    /// else the whole trimmed text.
    public static func extractJS(_ raw: String, entry: String? = nil) -> String {
        if let block = fencedBlock(raw, langs: ["js", "javascript", "typescript", "ts"]) { return block }
        if let block = fencedBlock(raw, langs: nil) { return block }
        // No fence: take from the first `function [entry]` to the last closing brace,
        // trimming any trailing prose the model appended after the code.
        if let entry, let r = raw.range(of: "function \(entry)") {
            return trimToLastBrace(String(raw[r.lowerBound...]))
        }
        if let r = raw.range(of: "function ") {
            return trimToLastBrace(String(raw[r.lowerBound...]))
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimToLastBrace(_ s: String) -> String {
        if let last = s.lastIndex(of: "}") {
            return String(s[...last]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Return the contents of the first fenced code block whose info-string matches
    /// one of `langs` (case-insensitive). Pass `langs: nil` to match any fence.
    private static func fencedBlock(_ raw: String, langs: [String]?) -> String? {
        let ns = raw as NSString
        // Match ```lang\n ... \n``` (non-greedy). The info-string is group 1.
        guard let re = try? NSRegularExpression(
            pattern: "```([A-Za-z0-9_+-]*)[ \\t]*\\r?\\n([\\s\\S]*?)```",
            options: []) else { return nil }
        let matches = re.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let lang = ns.substring(with: m.range(at: 1)).lowercased()
            let body = ns.substring(with: m.range(at: 2))
            if let langs {
                if langs.contains(lang) {
                    return body.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                return body.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}
