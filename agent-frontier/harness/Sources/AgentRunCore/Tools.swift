import Foundation

// Tools — the mock device/corpus tool catalog. Each tool reads args (a JSONValue
// object), optionally mutates DeviceState, and returns a JSONValue result. The same
// ToolSpec drives three things: execution (run), the model-facing tool catalogue in
// the prompt (name/summary/params), and the JS-bridge manifest (permission/side
// effects). One declaration, three consumers — so they cannot drift.

public struct Permission: Codable {
    public let domain: String          // "calendar" | "reminders" | "notes" | "photos" | "audio" | "corpus"
    public let access: String          // "read" | "write"
    public let userConsent: String     // "per-session" | "per-call" | "none"
    enum CodingKeys: String, CodingKey { case domain, access, userConsent = "user_consent" }
}

public struct ParamSpec: Codable {
    public let name: String
    public let type: String            // "string" | "string[]" | "date" (ISO8601)
    public let required: Bool
    public let about: String
}

public struct ToolSpec {
    public let name: String
    public let summary: String
    public let params: [ParamSpec]
    public let permission: Permission
    public let sideEffects: Bool
    public let run: (JSONValue, inout DeviceState) -> ToolOutcome
}

public struct ToolOutcome {
    public var result: JSONValue
    public var error: String?
    public init(_ result: JSONValue, error: String? = nil) { self.result = result; self.error = error }
    public static func fail(_ msg: String) -> ToolOutcome { ToolOutcome(.null, error: msg) }
}

public enum Tools {

    /// The full catalog, keyed by tool name. A task exposes a subset via its allowlist.
    public static let catalog: [String: ToolSpec] = {
        var m: [String: ToolSpec] = [:]
        for t in all { m[t.name] = t }
        return m
    }()

    public static let all: [ToolSpec] = [
        // ---- Calendar (read-only) ------------------------------------------
        ToolSpec(name: "calendar.list",
                 summary: "List calendar events, optionally filtered to a single day.",
                 params: [ParamSpec(name: "date", type: "string", required: false, about: "'YYYY-MM-DD'; omit for all events")],
                 permission: Permission(domain: "calendar", access: "read", userConsent: "per-session"),
                 sideEffects: false) { args, state in
            let date = args["date"]?.asString
            let rows = state.rows("calendar").filter { ev in
                guard let date else { return true }
                guard let start = ev["start"]?.asString else { return false }
                return start.hasPrefix(date)
            }
            return ToolOutcome(.array(rows))
        },
        ToolSpec(name: "calendar.get",
                 summary: "Get one calendar event by id.",
                 params: [ParamSpec(name: "id", type: "string", required: true, about: "event id")],
                 permission: Permission(domain: "calendar", access: "read", userConsent: "per-session"),
                 sideEffects: false) { args, state in
            guard let id = args["id"]?.asString else { return .fail("missing id") }
            guard let ev = state.rows("calendar").first(where: { $0["id"]?.asString == id }) else { return .fail("no event \(id)") }
            return ToolOutcome(ev)
        },

        // ---- Reminders -----------------------------------------------------
        ToolSpec(name: "reminders.create",
                 summary: "Create a reminder. Optional 'due' is an ISO8601 datetime with time-zone offset.",
                 params: [ParamSpec(name: "title", type: "string", required: true, about: "reminder title"),
                          ParamSpec(name: "due", type: "date", required: false, about: "ISO8601 datetime, e.g. 2026-07-14T09:00:00-07:00"),
                          ParamSpec(name: "notes", type: "string", required: false, about: "optional body")],
                 permission: Permission(domain: "reminders", access: "write", userConsent: "per-session"),
                 sideEffects: true) { args, state in
            guard let title = args["title"]?.asString, !title.isEmpty else { return .fail("missing title") }
            let id = state.nextGenId("reminder")
            var obj: [String: JSONValue] = ["id": .string(id), "title": .string(title)]
            if let due = args["due"]?.asString { obj["due"] = .string(due) }
            if let notes = args["notes"]?.asString { obj["notes"] = .string(notes) }
            state.append("reminders", .object(obj))
            return ToolOutcome(.object(["id": .string(id), "created": .bool(true)]))
        },
        ToolSpec(name: "reminders.list",
                 summary: "List existing reminders.",
                 params: [],
                 permission: Permission(domain: "reminders", access: "read", userConsent: "per-session"),
                 sideEffects: false) { _, state in ToolOutcome(.array(state.rows("reminders"))) },

        // ---- Notes ---------------------------------------------------------
        ToolSpec(name: "notes.search",
                 summary: "Search notes; returns notes whose title or body contains ALL query words.",
                 params: [ParamSpec(name: "query", type: "string", required: true, about: "space-separated search words")],
                 permission: Permission(domain: "notes", access: "read", userConsent: "per-session"),
                 sideEffects: false) { args, state in
            let q = args["query"]?.asString ?? ""
            let hits = state.rows("notes").filter { note in
                let hay = ((note["title"]?.asString ?? "") + " " + (note["body"]?.asString ?? "")).lowercased()
                return allTermsPresent(q, in: hay)
            }.map { note -> JSONValue in
                .object(["id": note["id"] ?? .null,
                         "title": note["title"] ?? .null,
                         "snippet": .string(String((note["body"]?.asString ?? "").prefix(80)))])
            }
            return ToolOutcome(.array(hits))
        },
        ToolSpec(name: "notes.get",
                 summary: "Get the full body of one note by id.",
                 params: [ParamSpec(name: "id", type: "string", required: true, about: "note id")],
                 permission: Permission(domain: "notes", access: "read", userConsent: "per-session"),
                 sideEffects: false) { args, state in
            guard let id = args["id"]?.asString else { return .fail("missing id") }
            guard let note = state.rows("notes").first(where: { $0["id"]?.asString == id }) else { return .fail("no note \(id)") }
            return ToolOutcome(note)
        },
        ToolSpec(name: "notes.create",
                 summary: "Create a new note with a title and body.",
                 params: [ParamSpec(name: "title", type: "string", required: true, about: "note title"),
                          ParamSpec(name: "body", type: "string", required: true, about: "note body")],
                 permission: Permission(domain: "notes", access: "write", userConsent: "per-session"),
                 sideEffects: true) { args, state in
            guard let title = args["title"]?.asString, let body = args["body"]?.asString else { return .fail("missing title/body") }
            let id = state.nextGenId("note")
            state.append("notes", .object(["id": .string(id), "title": .string(title), "body": .string(body)]))
            return ToolOutcome(.object(["id": .string(id), "created": .bool(true)]))
        },

        // ---- Photos --------------------------------------------------------
        ToolSpec(name: "photos.search",
                 summary: "Search photos; returns photos whose tags+kind contain ALL query words.",
                 params: [ParamSpec(name: "query", type: "string", required: true, about: "e.g. 'receipt screenshot'")],
                 permission: Permission(domain: "photos", access: "read", userConsent: "per-session"),
                 sideEffects: false) { args, state in
            let q = args["query"]?.asString ?? ""
            let hits = state.rows("photos").filter { p in
                let tags = (p["tags"]?.asArray ?? []).compactMap { $0.asString }.joined(separator: " ")
                let hay = (tags + " " + (p["kind"]?.asString ?? "")).lowercased()
                return allTermsPresent(q, in: hay)
            }
            return ToolOutcome(.array(hits))
        },
        ToolSpec(name: "photos.create_album",
                 summary: "Create a (empty) photo album with the given name.",
                 params: [ParamSpec(name: "name", type: "string", required: true, about: "album name")],
                 permission: Permission(domain: "photos", access: "write", userConsent: "per-session"),
                 sideEffects: true) { args, state in
            guard let name = args["name"]?.asString else { return .fail("missing name") }
            if state.rows("albums").contains(where: { $0["name"]?.asString == name }) {
                return ToolOutcome(.object(["album": .string(name), "created": .bool(false), "note": .string("already exists")]))
            }
            state.append("albums", .object(["name": .string(name), "ids": .array([])]))
            return ToolOutcome(.object(["album": .string(name), "created": .bool(true)]))
        },
        ToolSpec(name: "photos.add_to_album",
                 summary: "Add photo ids to an existing album (deduplicated).",
                 params: [ParamSpec(name: "album", type: "string", required: true, about: "album name (must exist)"),
                          ParamSpec(name: "ids", type: "string[]", required: true, about: "photo ids to add")],
                 permission: Permission(domain: "photos", access: "write", userConsent: "per-session"),
                 sideEffects: true) { args, state in
            guard let album = args["album"]?.asString else { return .fail("missing album") }
            let ids = (args["ids"]?.asArray ?? []).compactMap { $0.asString }
            var albums = state.rows("albums")
            guard let idx = albums.firstIndex(where: { $0["name"]?.asString == album }) else { return .fail("no album '\(album)' — create it first") }
            var existing = (albums[idx]["ids"]?.asArray ?? []).compactMap { $0.asString }
            var added = 0
            for id in ids where !existing.contains(id) { existing.append(id); added += 1 }
            albums[idx] = .object(["name": .string(album), "ids": .array(existing.map { .string($0) })])
            state.collections["albums"] = albums
            return ToolOutcome(.object(["album": .string(album), "added": .int(added), "count": .int(existing.count)]))
        },

        // ---- Audio (models the ASR step; transcript ships in initial_state) --
        ToolSpec(name: "audio.transcribe",
                 summary: "Transcribe a voice memo to text by id.",
                 params: [ParamSpec(name: "id", type: "string", required: true, about: "audio memo id")],
                 permission: Permission(domain: "audio", access: "read", userConsent: "per-session"),
                 sideEffects: false) { args, state in
            guard let id = args["id"]?.asString else { return .fail("missing id") }
            guard let memo = state.rows("audio_memos").first(where: { $0["id"]?.asString == id }) else { return .fail("no memo \(id)") }
            return ToolOutcome(.object(["id": .string(id),
                                        "transcript": memo["transcript"] ?? .string("")]))
        },

        // ---- Corpus (Tier D document research; read is what the revisit trace tracks)
        ToolSpec(name: "corpus.search",
                 summary: "Search the on-device document corpus; returns matching {id,title,snippet}.",
                 params: [ParamSpec(name: "query", type: "string", required: true, about: "space-separated search words")],
                 permission: Permission(domain: "corpus", access: "read", userConsent: "none"),
                 sideEffects: false) { args, state in
            let q = args["query"]?.asString ?? ""
            let hits = state.rows("corpus").filter { doc in
                let hay = ((doc["title"]?.asString ?? "") + " " + (doc["body"]?.asString ?? "")).lowercased()
                return anyTermPresent(q, in: hay)
            }.map { doc -> JSONValue in
                .object(["id": doc["id"] ?? .null,
                         "title": doc["title"] ?? .null,
                         "snippet": .string(String((doc["body"]?.asString ?? "").prefix(100)))])
            }
            return ToolOutcome(.array(hits))
        },
        ToolSpec(name: "corpus.read",
                 summary: "Read the full text of one corpus document by id.",
                 params: [ParamSpec(name: "id", type: "string", required: true, about: "document id")],
                 permission: Permission(domain: "corpus", access: "read", userConsent: "none"),
                 sideEffects: false) { args, state in
            guard let id = args["id"]?.asString else { return .fail("missing id") }
            guard let doc = state.rows("corpus").first(where: { $0["id"]?.asString == id }) else { return .fail("no document \(id)") }
            return ToolOutcome(doc)
        },
    ]

    // ---- match helpers -----------------------------------------------------
    // AND semantics: every whitespace-separated term must appear in the haystack.
    static func allTermsPresent(_ query: String, in hay: String) -> Bool {
        let terms = query.lowercased().split(whereSeparator: { $0 == " " }).map(String.init)
        return !terms.isEmpty && terms.allSatisfy { hay.contains($0) }
    }
    // OR semantics: used by corpus.search so a broad research query still retrieves.
    static func anyTermPresent(_ query: String, in hay: String) -> Bool {
        let terms = query.lowercased().split(whereSeparator: { $0 == " " }).map(String.init)
        return terms.contains { hay.contains($0) }
    }
}
