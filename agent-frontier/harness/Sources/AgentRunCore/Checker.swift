import Foundation

// Checker — evaluates a task's final_check against the final DeviceState, the finish
// answer, and the trace. Every assertion is deterministic: no model, no fuzzy matching
// beyond case-insensitive substring and ISO8601 instant equality. This is what makes a
// Tier-A/D pass mean something a third party can reproduce.
//
// Assertion kinds (all keyed by "kind"):
//   reminder_exists  {title_contains?, title_equals?, due?|due_instant?, min_count?}
//   reminder_count   {equals}
//   note_created     {title_contains?, title_equals?, body_contains?:[..]}   (created == id "gen_*")
//   album_exists     {name}
//   album_contains   {name, all_of?:[ids], min_count?}
//   album_excludes   {name, ids:[..]}
//   answer_contains  {all_of?:[..], any_of?:[..]}
//   tool_called      {tool, min_count?}
//   brief_cites      {doc_ids:[..], facts?:[..]}   (Tier D: answer must cite ids + contain facts)

public enum Checker {

    public static func evaluate(task: AgentTask, state: DeviceState, answer: String, trace: [JSONValue]) -> [CheckResult] {
        task.finalCheck.all.map { a in evalOne(a, state: state, answer: answer, trace: trace) }
    }

    private static func evalOne(_ a: JSONValue, state: DeviceState, answer: String, trace: [JSONValue]) -> CheckResult {
        let kind = a["kind"]?.asString ?? "?"
        switch kind {

        case "reminder_exists":
            let matches = state.rows("reminders").filter { reminderMatches($0, a) }
            let need = a["min_count"]?.asInt ?? 1
            return CheckResult(kind: kind, pass: matches.count >= need,
                               detail: "\(matches.count) reminder(s) match (need \(need))")

        case "reminder_count":
            let want = a["equals"]?.asInt ?? -1
            let got = state.rows("reminders").count
            return CheckResult(kind: kind, pass: got == want, detail: "reminders=\(got) want=\(want)")

        case "note_created":
            let created = state.rows("notes").filter { ($0["id"]?.asString ?? "").hasPrefix("gen_") }
            let matches = created.filter { noteMatches($0, a) }
            return CheckResult(kind: kind, pass: !matches.isEmpty,
                               detail: "\(matches.count)/\(created.count) created note(s) match")

        case "album_exists":
            let name = a["name"]?.asString ?? ""
            let ok = state.rows("albums").contains { $0["name"]?.asString == name }
            return CheckResult(kind: kind, pass: ok, detail: ok ? "album '\(name)' exists" : "no album '\(name)'")

        case "album_contains":
            let name = a["name"]?.asString ?? ""
            guard let album = state.rows("albums").first(where: { $0["name"]?.asString == name }) else {
                return CheckResult(kind: kind, pass: false, detail: "no album '\(name)'")
            }
            let ids = Set((album["ids"]?.asArray ?? []).compactMap { $0.asString })
            let allOf = (a["all_of"]?.asArray ?? []).compactMap { $0.asString }
            let minCount = a["min_count"]?.asInt
            let hasAll = allOf.allSatisfy { ids.contains($0) }
            let hasCount = minCount == nil || ids.count >= minCount!
            return CheckResult(kind: kind, pass: hasAll && hasCount,
                               detail: "album '\(name)' has \(ids.sorted()); need all_of=\(allOf) min=\(minCount.map(String.init) ?? "-")")

        case "album_excludes":
            let name = a["name"]?.asString ?? ""
            let album = state.rows("albums").first(where: { $0["name"]?.asString == name })
            let ids = Set((album?["ids"]?.asArray ?? []).compactMap { $0.asString })
            let banned = (a["ids"]?.asArray ?? []).compactMap { $0.asString }
            let intruders = banned.filter { ids.contains($0) }
            return CheckResult(kind: kind, pass: intruders.isEmpty,
                               detail: intruders.isEmpty ? "none of \(banned) present" : "unwanted ids present: \(intruders)")

        case "answer_contains":
            let hay = answer.lowercased()
            let allOf = (a["all_of"]?.asArray ?? []).compactMap { $0.asString }
            let anyOf = (a["any_of"]?.asArray ?? []).compactMap { $0.asString }
            let okAll = allOf.allSatisfy { hay.contains($0.lowercased()) }
            let okAny = anyOf.isEmpty || anyOf.contains { hay.contains($0.lowercased()) }
            return CheckResult(kind: kind, pass: okAll && okAny,
                               detail: "all_of=\(allOf) any_of=\(anyOf)")

        case "tool_called":
            let tool = a["tool"]?.asString ?? ""
            let need = a["min_count"]?.asInt ?? 1
            let n = trace.filter { $0["type"]?.asString == "round"
                && $0["action"]?.asString == "call" && $0["tool"]?.asString == tool }.count
            return CheckResult(kind: kind, pass: n >= need, detail: "\(tool) called \(n)x (need \(need))")

        case "brief_cites":
            let hay = answer.lowercased()
            let docIds = (a["doc_ids"]?.asArray ?? []).compactMap { $0.asString }
            let facts = (a["facts"]?.asArray ?? []).compactMap { $0.asString }
            let citesAll = docIds.allSatisfy { hay.contains($0.lowercased()) }
            let factsAll = facts.allSatisfy { hay.contains($0.lowercased()) }
            let missingCites = docIds.filter { !hay.contains($0.lowercased()) }
            let missingFacts = facts.filter { !hay.contains($0.lowercased()) }
            return CheckResult(kind: kind, pass: citesAll && factsAll,
                               detail: "missing cites=\(missingCites) missing facts=\(missingFacts)")

        default:
            return CheckResult(kind: kind, pass: false, detail: "unknown assertion kind '\(kind)'")
        }
    }

    // ---- predicate helpers -------------------------------------------------
    private static func reminderMatches(_ r: JSONValue, _ a: JSONValue) -> Bool {
        if let tc = a["title_contains"]?.asString,
           !(r["title"]?.asString ?? "").lowercased().contains(tc.lowercased()) { return false }
        if let te = a["title_equals"]?.asString, r["title"]?.asString != te { return false }
        if let due = (a["due"]?.asString ?? a["due_instant"]?.asString) {
            guard let want = parseInstant(due), let got = (r["due"]?.asString).flatMap(parseInstant),
                  abs(want.timeIntervalSince(got)) < 1.0 else { return false }
        }
        return true
    }

    private static func noteMatches(_ n: JSONValue, _ a: JSONValue) -> Bool {
        if let tc = a["title_contains"]?.asString,
           !(n["title"]?.asString ?? "").lowercased().contains(tc.lowercased()) { return false }
        if let te = a["title_equals"]?.asString, n["title"]?.asString != te { return false }
        let body = (n["body"]?.asString ?? "").lowercased()
        for f in (a["body_contains"]?.asArray ?? []).compactMap({ $0.asString }) {
            if !body.contains(f.lowercased()) { return false }
        }
        return true
    }

    // ISO8601 with time-zone offset (or Z), with and without fractional seconds. Instant
    // comparison means "2026-07-15T09:00:00+09:00" equals "2026-07-14T17:00:00-07:00".
    public static func parseInstant(_ s: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }
}
