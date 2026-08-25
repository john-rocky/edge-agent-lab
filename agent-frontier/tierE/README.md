# Tier E — long-horizon endurance (CPU harness built; GPU run pending)

The kickoff's top rung: a **20+ tool-call chain** to find *where* round-count degrades a small
model. Built as CPU-self-testable tasks (P0/P1 discipline) that **reuse the Runner, Tools, and
Checker unchanged** — no new assertion kinds. Two tasks isolate the two long-horizon failure
modes:

| task | failure mode | chain | degradation profile |
|------|--------------|-------|---------------------|
| `tierE_breadcrumb_chain` | **sequential dependency** — each read reveals the next doc id | search + 20 dependent `corpus.read` | how many hops before it loses the trail |
| `tierE_batch_followups` | **repetition** — one reminder per meeting, N=20 | `calendar.list` + 20 `reminders.create` | which items get dropped/duplicated, and whether failures cluster late |

**Why many single-item assertions.** Each task's `final_check` is a *list* of one-item
assertions (one `answer_contains`/`reminder_exists` per codeword/meeting). The Checker reports one
`CheckResult` per assertion, so the pass/fail breakdown **is** the degradation curve — the first
`·` in the `✓✓✓···` profile marks the onset. No graded checker kind needed; the existing per-
assertion reporting does it.

## Self-test (CPU, no GPU, no model)

```bash
cd ../harness && swift build -c release
./.build/release/agentrun selftest --tasks ../tierE     # mock PASS, null FAIL → checker discriminates
```

Verified 2026-07-14: both tasks PASS/FAIL cleanly (`checks=4  task-mismatches=0`). A truncated
mock confirms the profile is granular — an agent that finishes 12 of 20 items scores
`✓✓✓✓✓✓✓✓✓✓✓✓·········` (onset at item 12); 9 of 20 hops → `✓✓✓✓✓✓✓✓✓·············`.

## Regenerate / sweep N

`gen_tierE.py` emits both tasks (canonical N=20, committed). Parameterized so the GPU session can
sweep N to locate the onset:

```bash
python3 gen_tierE.py            # N=20 → the two committed files
python3 gen_tierE.py 30 sweep   # → tierE_*_n30.json (uncommitted; for the sweep)
```

## Hand-off to the GPU session

Everything above is done and needs no compute. The model run is one command, GPU-gated:

```bash
cd .. && ./driver/run_tierE.sh              # 2B on both tasks (self-acquires/releases _GPU_LOCK)
MODELS="0.8b 2b" ./driver/run_tierE.sh      # both sizes
```

It prints each task's `✓/·` profile + the degradation onset. What to record:
- **Onset depth** per task/model (first `·`). Breadcrumb: the hop it loses coherence. Batch: the
  item index where drops start (item k lands ~round k+1 → onset index ≈ round depth).
- **Compare to the short chains** (Tier-A 6-round, Tier-D 3-round): does a 20-step task degrade
  *earlier per step* than a short one, or only run out of rounds? That's the endurance finding.
- **Failure texture** from the trace (`phaseE/trace_*.jsonl`): does batch drop late items, or
  loop/duplicate (watch the `repeat` nudges)? Does breadcrumb read a decoy and derail?
- Fold the result into `../AGENT_STATE.md` as **GATE-RESULT P2b** and the report's contour map.
