# Tier D — document research (the prefix-cache layer)

Kickoff Tier D: *"端末内コーパス10文書→引用つきブリーフ. prefix cacheが最も輝く層
(コーパスをラウンド毎に再訪する)"* — a 10-document on-device corpus, and a task that
produces a **cited brief** over it. This is the rung where prefix-cache (turn-to-turn KV
reuse) matters most, because a research loop re-reads the same corpus prefix across rounds.

## The corpus

10 short documents about a **fictional** product line ("Project Aurora"). Synthetic on
purpose: the facts are controllable and there is no copyright to launder. Distractors (d8
office move, d9 holidays) are mixed in so retrieval has to discriminate. The corpus is
**embedded in the task JSON** (`tierD_aurora_brief.json` → `initial_state.corpus`) so the
task stays the portable unit — one file, no external resolution. The doc ids and titles:

| id | title | role |
|----|-------|------|
| d1 | Aurora — overview | context |
| d2 | Aurora — model card | context |
| d3 | Aurora — benchmarks | context |
| d4 | Aurora — pricing | context |
| d5 | Aurora — roadmap | **launch date (2026-09-15)** |
| d6 | Aurora — ownership | **owners (Priya Nair, Sam Okafor)** |
| d7 | Aurora — risks | cross-reference (date ↔ security) |
| d8 | Office move memo | distractor |
| d9 | Holiday schedule | distractor |
| d10 | Aurora — security review | security sign-off detail |

## Why the trace records "corpus revisits"

The runner tags every `corpus.read`: `{round, doc, first_time}`, and tracks the growing
set of distinct docs in context (`context_growth`). A re-read (`first_time:false`) is a
round whose input **prefix is already warm** — exactly the KV a prefix cache would reuse
instead of re-prefilling. The reference solution deliberately re-reads `d5` after reading
the risk note `d7`, so the self-test trace shows `reread_count: 1` and a `context_growth`
that stays flat on the re-read round.

This is the *seed* for the prefix-cache comparison the kickoff wants (Mac
sequential-engine + `trimKVCache`, memory `project_prefix_cache_kv_reuse`). Building the
warm-KV runner is the deferred heavy-wiring job; Tier D's contribution is the **task and
the trace shape** that make "round 3: 8 s → 0.3 s" measurable once that runner exists. The
requirement spec for it lives in `../SPEC_prefix_cache_runner.md`.
