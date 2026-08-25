# agent-frontier

The measurement behind [`docs/codeact-vs-tool-calling.md`](../docs/codeact-vs-tool-calling.md):
on a phone-sized model, does a multi-step agent do better writing one program that calls the
tools, or one tool call per round?

Everything here except the model runs is CPU-only and has no dependencies beyond Foundation and
the system JavaScriptCore. It builds and self-tests in about ten seconds.

```bash
cd harness && swift build -c release
./.build/release/agentrun codeact-selftest --tasks ../tierA --ref-dir ../codeact
```

That command is the control for the whole result. It runs a hand-written CodeAct program that
solves each task, and an empty one, through the same sandbox and the same assertions the model's
programs go through. The reference must pass and the empty must fail, or the 0/3 in the note
would be a statement about the harness rather than about the model.

## Layout

| | |
|---|---|
| `harness/` | the Swift package: `jsprobe` (run candidate JS in a watchdogged `JSContext`), `agentrun` (the agent loop, the mock device tools, the checker, the CodeAct arm) |
| `tasks/` | Phase A — 10 pure-function JS tasks, with `solutions/` and `broken/` so the checker can be shown to discriminate |
| `tierA/`, `tierD/`, `tierE/` | agent tasks: short device chores, document research, long-horizon |
| `codeact/` | one hand-written CodeAct program per task — the control |
| `prompts/` | the system prompts each rung was run with |
| `runs/` | every model run behind the note: traces, results, and each program the model wrote |
| `FORMATS.md` | the three file formats — task definition, JS-bridge manifest, execution trace |

## Reading a result

Numbers in the note come from `runs/`, and each is checkable without a GPU:

```bash
# tool-calling, 2B: both device chores pass, the research task does not
grep -h '"ok"' runs/phaseD_hardened2/trace_*.jsonl | tail -3

# CodeAct self-repair emitted the same program four times
md5 -q runs/phaseD_codeact_i/qwen3.5-2B/work_tierA_photo_album/prog_a*.js | sort -u | wc -l
```

## The permission model

```bash
./.build/release/agentrun manifest --task ../tierA/tierA_meeting_followup.json
```

This prints the host functions exported into the sandbox for that task. That set is what a
generated program can touch, and it is emitted from the same tool catalog the runner executes —
so the declared surface cannot drift from the executed one. App Store rule 2.5.2 makes
`JSContext` the only way to run generated code on iOS, so on that platform this is the whole
attack surface, readable before anything runs.

## What is not here

The model runs themselves. They use the leaderboard's deterministic eval driver over two
exported int8 bundles (qwen3.5-0.8B, qwen3.5-2B) on a Mac GPU, and that driver lives with the
model stack rather than here. The traces those runs produced are in `runs/`, so every claim in
the note can be checked without re-running them.
