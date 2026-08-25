import Foundation

// JSONValue — a small, Equatable, order-preserving-enough JSON model used as the
// lingua franca of the agent runner: tool arguments, tool results, device-state
// entities, and trace records are all JSONValue. Kept separate from JSProbeCore's
// AnyCodable so AgentRunCore has no JavaScriptCore dependency (the mock path is
// pure Foundation and builds/self-tests in seconds).
public indirect enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    // ---- convenience accessors --------------------------------------------
    public var asString: String? { if case .string(let s) = self { return s }; return nil }
    public var asInt: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }
    public var asArray: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    public var asObject: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }

    public subscript(_ key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    // Compact, deterministic serialization (sorted keys) for trace/manifest output.
    public func jsonString(pretty: Bool = false) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        guard let d = try? enc.encode(self), let s = String(data: d, encoding: .utf8) else { return "null" }
        return s
    }

    public static func parse(_ s: String) -> JSONValue? {
        guard let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: d)
    }
}
