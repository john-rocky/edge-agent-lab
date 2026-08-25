import Foundation

// AgentTask — the Tier-A / Tier-D task-definition format (documented in FORMATS.md §4).
//
// This is the stateful, tool-calling sibling of Phase A's TaskSpec: instead of a pure
// function scored on return values, a task carries an initial device world, a tool
// allowlist, and a deterministic final-state check. The portable unit is one JSON file.
public struct AgentTask: Codable {
    public let id: String
    public let title: String
    public let tier: String                 // "tierA" | "tierD"
    public let source: String               // demand-trace citation
    public let spec: String                 // the natural-language instruction handed to the agent
    public let now: String?                 // injected device clock (ISO8601 with offset); optional
    public let timezone: String?            // device IANA time zone; optional
    public let maxRounds: Int
    public let toolAllowlist: [String]
    public let initialState: [String: JSONValue]   // collection name -> array of entities
    public let finalCheck: FinalCheck
    public let mockSolution: [MockStep]     // reference tool-call script for harness self-test

    enum CodingKeys: String, CodingKey {
        case id, title, tier, source, spec, now, timezone
        case maxRounds = "max_rounds"
        case toolAllowlist = "tool_allowlist"
        case initialState = "initial_state"
        case finalCheck = "final_check"
        case mockSolution = "mock_solution"
    }

    public struct FinalCheck: Codable {
        public let all: [JSONValue]         // each element is an assertion object with a "kind"
    }

    // A mock step is either { "call": {tool, args} } or { "finish": "answer text" }.
    public enum MockStep: Codable {
        case call(tool: String, args: JSONValue)
        case finish(String)

        public init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            let v = try c.decode(JSONValue.self)
            if let call = v["call"], let tool = call["tool"]?.asString {
                self = .call(tool: tool, args: call["args"] ?? .object([:]))
            } else if let f = v["finish"]?.asString {
                self = .finish(f)
            } else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "mock step needs 'call' or 'finish'")
            }
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .call(let tool, let args):
                try c.encode(JSONValue.object(["call": .object(["tool": .string(tool), "args": args])]))
            case .finish(let s):
                try c.encode(JSONValue.object(["finish": .string(s)]))
            }
        }
    }

    public static func load(_ url: URL) throws -> AgentTask {
        try JSONDecoder().decode(AgentTask.self, from: try Data(contentsOf: url))
    }
}
