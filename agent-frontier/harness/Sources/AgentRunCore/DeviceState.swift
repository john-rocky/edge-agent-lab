import Foundation

// DeviceState — the mutable mock world a task runs against. Collections are generic
// arrays of JSON objects ("calendar", "reminders", "notes", "photos", "albums",
// "audio_memos", "corpus"), which lets one runner serve both Tier A (device chores)
// and Tier D (document corpus) without bespoke types. Real EventKit/Photos/Speech
// wiring is a v1 concern; here every entity ships inside the task's initial_state.
public struct DeviceState {
    public var now: String
    public var timezone: String
    public var collections: [String: [JSONValue]]
    private var genCounter = 0

    public init(task: AgentTask) {
        self.now = task.now ?? "1970-01-01T00:00:00Z"
        self.timezone = task.timezone ?? "UTC"
        var cols: [String: [JSONValue]] = [:]
        for (name, value) in task.initialState {
            cols[name] = value.asArray ?? []
        }
        // Ensure the standard collections exist even when the task omits them.
        for name in ["calendar", "reminders", "notes", "photos", "albums", "audio_memos", "corpus"] {
            if cols[name] == nil { cols[name] = [] }
        }
        self.collections = cols
    }

    // A stable, tool-created id so the checker can tell created entities from seeded ones.
    public mutating func nextGenId(_ prefix: String) -> String {
        genCounter += 1
        return "gen_\(prefix)_\(genCounter)"
    }

    public func rows(_ collection: String) -> [JSONValue] { collections[collection] ?? [] }

    public mutating func append(_ collection: String, _ row: JSONValue) {
        collections[collection, default: []].append(row)
    }

    // A short digest of mutable, side-effect-bearing collections — recorded per round in
    // the trace so a reader can see the world change without dumping the whole state.
    public func digest() -> JSONValue {
        .object([
            "reminders": .int(rows("reminders").count),
            "notes": .int(rows("notes").count),
            "albums": .int(rows("albums").count),
        ])
    }
}
