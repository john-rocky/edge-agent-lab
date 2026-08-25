import Foundation

// TaskSpec — the task-definition format (documented in FORMATS.md).
//
// This is the FIRST-class artifact of AGENT-P0: a portable, third-party-usable
// description of "one on-device coding task". Everything else (harness, prompt,
// driver) is downstream of it. One JSON file per task in tasks/*.json.

public struct TaskSpec: Codable {
    public let id: String
    public let title: String
    public let tier: String            // "humaneval" | "automation"
    public let source: String          // demand-trace citation (why this task exists)
    public let entry: String           // function name the solution must define
    public let prompt: String          // natural-language spec handed to the model
    public let signature: String       // one-line type hint, shown to the model
    public let timeoutMs: Double?
    public let tests: [TestVector]

    public struct TestVector: Codable {
        public let args: [AnyCodable]   // argument list for one call
        public let expect: AnyCodable   // expected return value
    }

    enum CodingKeys: String, CodingKey {
        case id, title, tier, source, entry, prompt, signature
        case timeoutMs = "timeout_ms", tests
    }

    public var effectiveTimeoutMs: Double { timeoutMs ?? 2000 }

    public var argsList: [Any] { tests.map { $0.args.map { $0.value } } }
    public var expects: [Any] { tests.map { $0.expect.value } }

    public static func load(_ url: URL) throws -> TaskSpec {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TaskSpec.self, from: data)
    }
}

// AnyCodable — decode/encode arbitrary JSON scalars/arrays/objects, preserving
// booleans vs numbers (JSONSerialization is used for the eventual JS marshaling).
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = NSNull(); return }
        if let b = try? c.decode(Bool.self) { value = b; return }
        if let i = try? c.decode(Int.self) { value = i; return }
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self) { value = s; return }
        if let a = try? c.decode([AnyCodable].self) { value = a.map { $0.value }; return }
        if let o = try? c.decode([String: AnyCodable].self) {
            value = o.mapValues { $0.value }; return
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let b as Bool: try c.encode(b)
        case let i as Int: try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        case let a as [Any]: try c.encode(a.map { AnyCodable($0) })
        case let o as [String: Any]: try c.encode(o.mapValues { AnyCodable($0) })
        default: try c.encodeNil()
        }
    }
}
