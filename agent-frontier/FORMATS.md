# agent-frontier formats

The kickoff's discipline note ranks the *formats* the harness produces above the code
(SWE-bench logic: a format becomes a standard the moment a third party uses it). These
are kept small and separable on purpose. Priority order from the kickoff:

1. **Task-definition format** — two flavors: Phase-A pure functions (§1) and Tier-A/D
   stateful tool-calling tasks (§2). Stable.
2. **JS-bridge manifest** (capability + permission declaration) — §3. Now drafted (was
   deferred in P0); generated from the tool catalog. *Format only — nothing enforces it yet.*
3. **Execution-trace / result format** — §4. Phase-A `ProbeResult` + the Tier-A/D agent
   trace (JSONL). Stable.
4. Code (the harness) — downstream of the above.

---

## 1. Phase-A task definition (`tasks/<id>.json`)

One JSON file per task. The portable unit — a third party adds a task by dropping in a
file. Pure data-in/data-out: the model writes a function, the harness scores its return
values. No device state, no tools.

```jsonc
{
  "id": "he_sum_evens",           // unique, == filename stem
  "title": "Sum of even numbers", // human label
  "tier": "humaneval",            // "humaneval" | "automation"
  "source": "…",                  // REQUIRED demand-trace: why this task exists (evidence, not opinion)
  "entry": "sumEvens",            // the function name the solution MUST define
  "signature": "function sumEvens(nums)  // nums: number[] -> number",  // one-line type hint
  "prompt": "Write a JavaScript function …",  // the natural-language spec the model sees
  "timeout_ms": 2000,             // optional; watchdog budget per test call (default 2000)
  "tests": [                      // >= 3 vectors
    { "args": [[1, 2, 3, 4]], "expect": 6 },   // args = the FULL argument list for one call
    { "args": [[]],           "expect": 0 }    // expect = deep-equal target (any JSON value)
  ]
}
```

- `args` is always the argument *list*. A one-argument call taking an array is
  `"args": [[1,2,3,4]]` (outer list = arguments, inner = the array argument).
- `expect` is an order-independent deep-equal (object key order ignored; numbers within
  1e-6 relative). Design expected values to be exactly representable.

## 2. Tier-A / Tier-D task definition (`tierA/<id>.json`, `tierD/<id>.json`)

The stateful, tool-calling sibling of §1. Instead of a pure function scored on return
values, a task carries an **initial device world**, a **tool allowlist**, and a
**deterministic final-state check**. The agent runs a multi-round loop (pick a tool, pass
args, see the result, repeat) and is scored on what it *did to the world* + what it said.
Still one JSON file = one portable task. (The kickoff calls this the "task-definition
YAML"; it is rendered as JSON to reuse the Phase-A tooling and avoid a YAML parser
dependency in the Swift harness — the shape is identical.)

```jsonc
{
  "id": "tierA_meeting_followup",
  "title": "Meeting → follow-up reminder",
  "tier": "tierA",                       // "tierA" (device chore) | "tierD" (doc research)
  "source": "RESEARCH_TIERA.md #3 …",    // REQUIRED demand-trace citation
  "spec": "…natural-language instruction handed to the agent…",
  "now": "2026-07-13T08:30:00-07:00",    // optional: injected device clock (ISO8601 + offset)
  "timezone": "America/Los_Angeles",     // optional: device IANA time zone
  "max_rounds": 6,                       // hard cap on the loop (a runaway is not a pass)
  "tool_allowlist": ["calendar.list", "reminders.create", "reminders.list"],
  "initial_state": {                     // the mock world: collection name -> array of JSON entities
    "calendar":  [ { "id": "e1", "title": "…", "start": "…", "end": "…", "attendees": ["Dana"] } ],
    "reminders": []
  },
  "final_check": {                       // deterministic assertions (see kinds below)
    "all": [
      { "kind": "reminder_exists", "title_contains": "Dana", "due": "2026-07-14T09:00:00-07:00" },
      { "kind": "reminder_count",  "equals": 1 }
    ]
  },
  "mock_solution": [                     // reference tool-call script for harness self-test (no model)
    { "call": { "tool": "calendar.list",     "args": { "date": "2026-07-13" } } },
    { "call": { "tool": "reminders.create",  "args": { "title": "Follow up with Dana", "due": "2026-07-14T09:00:00-07:00" } } },
    { "finish": "Created a follow-up reminder." }
  ]
}
```

**Collections** (generic arrays of JSON objects, so one runner serves both tiers):
`calendar`, `reminders`, `notes`, `photos`, `albums`, `audio_memos`, `corpus`. Entities
created by tools get ids prefixed `gen_` so the checker can distinguish them from seeded
ones. Real EventKit/Photos/Speech wiring is a v1 concern; here everything ships in
`initial_state`.

**Tool catalog** (a task exposes a subset via `tool_allowlist`; args are a JSON object):
`calendar.list/get`, `reminders.create/list`, `notes.search/get/create`,
`photos.search/create_album/add_to_album`, `audio.transcribe`, `corpus.search/read`.
`notes.search`/`photos.search` use AND-of-terms matching; `corpus.search` uses OR (a broad
research query still retrieves). A call to a tool outside the allowlist is recorded as an
error round and does **not** mutate state — the allowlist is the sandbox boundary.

**`final_check` assertion kinds** (all deterministic; case-insensitive substrings, ISO8601
*instant* equality so `+09:00` and `-07:00` spellings of the same moment match):

| kind | fields | passes when |
|------|--------|-------------|
| `reminder_exists` | `title_contains?`, `title_equals?`, `due?`\|`due_instant?`, `min_count?` | ≥ `min_count` (default 1) reminders match every predicate |
| `reminder_count` | `equals` | reminder count == `equals` |
| `note_created` | `title_contains?`, `title_equals?`, `body_contains?:[…]` | a `gen_`-created note matches |
| `album_exists` | `name` | an album with that name exists |
| `album_contains` | `name`, `all_of?:[ids]`, `min_count?` | album has all listed ids / ≥ min_count |
| `album_excludes` | `name`, `ids:[…]` | none of those ids are in the album (precision) |
| `answer_contains` | `all_of?:[…]`, `any_of?:[…]` | the finish answer contains the substrings |
| `tool_called` | `tool`, `min_count?` | the tool was invoked ≥ min_count times (process assertion, over the trace) |
| `brief_cites` | `doc_ids:[…]`, `facts?:[…]` | the answer cites every doc id and contains every fact (Tier-D) |

`mock_solution` is the reference script the harness replays (via `MockBrain`) to prove the
task is *solvable* and the checker *discriminates*: `agentrun selftest` runs it (must PASS)
and a do-nothing `NullBrain` (must FAIL) for every task.

## 3. JS-bridge manifest (byproduct ②)

The kickoff's thesis: on iOS, the set of host functions you JSExport into the
JavaScriptCore sandbox **is** the agent's permission model (App Store rule 2.5.2 makes
JSCore the only legal path to run generated code, so the bridge choice = the security
boundary). This manifest writes that boundary down. It is **generated from the tool
catalog** (`agentrun manifest [--task <f> | --all]`) so the *declared* surface cannot drift
from the *executed* surface. Enforcement is out of scope — the deliverable is the format.

```jsonc
{
  "manifest_version": "0.1",
  "runtime": {                    // what the sandbox itself allows
    "engine": "JavaScriptCore",
    "network": false, "filesystem": false, "timers": false,
    "timeout_ms_default": 2000,
    "notes": "Only the capabilities below are JSExported. Absent capabilities are unreachable, not merely disallowed."
  },
  "grants": {                     // roll-up: which domains, can it write, consent model
    "domains": ["calendar", "reminders"],
    "can_write": true,
    "consent_model": "per-session grant per domain; a per-call prompt is a stricter variant a host may choose"
  },
  "capabilities": [               // one entry per bridged tool
    {
      "name": "reminders.create",
      "summary": "Create a reminder…",
      "permission": { "domain": "reminders", "access": "write", "user_consent": "per-session" },
      "side_effects": true,
      "params": [ { "name": "title", "type": "string", "required": true, "about": "…" }, … ]
    }
  ]
}
```

The point for the Apple conversation: a reviewer (or an OS) can read this manifest and know
*exactly* what a generated script can touch, before it runs — a concrete answer to
"how do you make on-device agents safe?".

## 4. Execution-trace / result formats

### 4a. Phase-A result (`ProbeResult`, from `jsprobe run|grade`)

```jsonc
{
  "ok": true,                 // pass@1: define succeeded AND every test vector passed
  "define_error": null,       // syntax error / top-level throw while defining (omitted when null)
  "pass_count": 5, "test_count": 5,
  "tests": [ { "pass": true, "got": "6", "error": null }, … ],
  "logs": "", "wall_ms": 1.98
}
```
Rolled up per model by `score_phaseB.py` into `phaseB/score_<model>.json` (pass@1 + by_tier).

### 4b. Agent trace (`agentrun run --trace <out.jsonl>`) — one JSONL file per run

```jsonc
{"type":"meta",   "task":"…","tier":"…","brain":"mock|model:…","spec":"…","now":"…","timezone":"…","max_rounds":6,"tool_allowlist":[…]}
{"type":"round",  "i":0,"action":"call","tool":"reminders.create","args":{…},"result":{…},"error":null,"state":{"reminders":1,…}}
{"type":"round",  "i":1,"action":"finish","answer":"…"}
{"type":"result", "ok":true,"rounds":2,"final_answer":"…","checks":[{"kind":"…","pass":true,"detail":"…"}],
                  "corpus_revisits":{…},"wall_ms":2.7}
```

- A `round` line records the action, the exact args, the tool result, and a digest of the
  mutable collections after the call — a reader sees the world change without a full dump.
- `corpus_revisits` (Tier-D) is the seed for the prefix-cache comparison: every `corpus.read`
  is tagged `{round, doc, first_time}`, and `context_growth` tracks distinct docs in context.
  A re-read (`first_time:false`) is a round whose input prefix is already warm — the KV a
  prefix cache would reuse. See `tierD/README.md` and `SPEC_prefix_cache_runner.md`.

## 5. Prompt contracts

- **Phase A** (`jsprobe prompt --task <f>`): steers a small model to one ```js block; the
  extractor tolerates prose leakage / missing language tag. See `prompts/NOTES.md`.
- **Tier A/D** (`agentrun prompt --task <f>`): the *tool-calling* protocol — a system turn
  listing the allowlisted tools and demanding EXACTLY ONE JSON object per turn
  (`{"tool":…,"args":…}` or `{"finish":…}`), then a user turn with the spec + running
  transcript. The parser is tolerant (finds the first balanced JSON object; accepts
  `{name,arguments}` too). This is the baseline the CodeAct comparison (Phase D) measures against.

- **Citation scaffold** (`agentrun prompt --task <f> --cite slot|readcite`; `AgentPrompt.CiteMode`):
  an opt-in variant of the tool-calling protocol that adds a structured citation slot to the
  finish form — `{"finish":"…","cited_ids":["<id>", …]}` — so a Tier-D "cite your sources" task
  can be scored on a *format* the model fills, not on ids buried in prose. Three rungs:
  `off` (baseline, no slot), `slot` (the slot + "cited_ids MUST list the ids that support your
  summary"), `readcite` (`slot` + "you may cite a doc only after you corpus.read it"). The
  example ids in the system prompt are placeholders (`"<id>"`), never real corpus ids, so the
  scaffold cannot leak the answer. `parse` folds `cited_ids` into the finish answer as
  `… [sources: d5, d6]`, so the SAME deterministic `brief_cites` check (§2) scores it with no
  checker change; folding is a no-op in `off` (the field is never emitted). This is the P2c
  probe that isolates "format" from "reasoning" (`../AGENT_STATE.md` GATE-RESULT P2c).
