import Foundation

// Brain — the pluggable decision-maker inside the agent loop. It sees the task, the
// running transcript, and the tool catalog, and returns the next action (a tool call
// or a finish). The runner (loop + trace + checker) is identical regardless of brain,
// which is the whole point: swap MockBrain <-> a model-backed brain and measure the
// same tasks the same way.
//
//   MockBrain    — replays a task's reference `mock_solution`. Deterministic, no model,
//                  no GPU. This is what makes the harness self-testable on CPU.
//   (model brain) — a brain that renders RoundContext into a prompt (see Prompt.swift),
//                  asks a small model for one tool call as JSON, and parses it. Kept out
//                  of AgentRunCore so this library has no engine dependency; the CLI's
//                  model mode supplies it. The heavy prefix-cache/session wiring is a
//                  separate session's job (kickoff "やらないこと").

public struct ToolCall: Equatable {
    public let tool: String
    public let args: JSONValue
    public init(tool: String, args: JSONValue) { self.tool = tool; self.args = args }
}

public enum BrainAction {
    case call(ToolCall)
    case finish(String)
}

public struct TranscriptEntry {
    public let tool: String
    public let args: JSONValue
    public let result: JSONValue
    public let error: String?
}

public struct RoundContext {
    public let task: AgentTask
    public let round: Int
    public let state: DeviceState
    public let transcript: [TranscriptEntry]
    public let tools: [ToolSpec]         // the allowlisted subset, in allowlist order
    public init(task: AgentTask, round: Int, state: DeviceState, transcript: [TranscriptEntry], tools: [ToolSpec]) {
        self.task = task; self.round = round; self.state = state
        self.transcript = transcript; self.tools = tools
    }
}

public protocol Brain {
    var label: String { get }
    mutating func next(_ ctx: RoundContext) throws -> BrainAction
}

// Replays the reference script. When the script is exhausted it finishes, so a task
// whose mock_solution forgets a trailing finish still terminates cleanly.
public struct MockBrain: Brain {
    public let label = "mock"
    private var steps: [AgentTask.MockStep]
    private var cursor = 0
    public init(_ task: AgentTask) { self.steps = task.mockSolution }

    public mutating func next(_ ctx: RoundContext) throws -> BrainAction {
        guard cursor < steps.count else { return .finish("(mock script exhausted)") }
        let step = steps[cursor]; cursor += 1
        switch step {
        case .call(let tool, let args): return .call(ToolCall(tool: tool, args: args))
        case .finish(let s): return .finish(s)
        }
    }
}
