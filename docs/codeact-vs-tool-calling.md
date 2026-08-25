# Whole-program CodeAct loses to step-wise tool-calling on a phone-sized model

Measured 2026-07-13/14 on qwen3.5-0.8B and qwen3.5-2B, both int8, greedy, Mac GPU.
Published 2026-08-25.

We expected the opposite. The bet was that **CodeAct** — the model writes one JavaScript
program that loops and calls the tools, and the host runs it in a single round — is the
phone-native shape. A small model pays a context tax every round it has to re-read a growing
transcript. Write the whole plan once and you skip the tax.

On the same three tasks, with the same checker, it lost 0/3 to 2/3.

| task | tool-calling 0.8B | tool-calling 2B | CodeAct 2B |
|---|:---:|:---:|:---:|
| meeting_followup | ✗ | **✓** | ✗ |
| photo_album | ✗ | **✓** | ✗ |
| aurora_brief | ✗ | ✗ | ✗ |
| | 0/3 | **2/3** | **0/3** |

The CodeAct column is 0/3 at all five rungs: naive prompt, hardened prompt, few-shot,
interactive self-repair, diverse self-repair. The tool-calling column replicates across four
independent runs — both Tier-A tasks pass every time, in 5–6 rounds; `aurora_brief` fails every
time.

## The control comes first

A 0/3 on a new harness is worth nothing until you know the harness can produce a 3/3. So the
checker is fed a hand-written CodeAct program that solves each task, and an empty one:

```
task                    ref   empty  verdict
tierA_meeting_followup  PASS  FAIL   ok
tierA_photo_album       PASS  FAIL   ok
CODEACT SELFTEST: PASS
```

A correct program passes and an empty program fails, through the same JavaScriptCore bridge and
the same assertions the model's programs run through. The 0/3 is about the model.

## Five rungs, because "the model failed" is not a finding

The programs were read, not assumed. Each rung removes one explanation for the failure, and the
score stays at 0/3 while the *reason* moves.

**Naive.** Real model errors: destructuring the tools off `window`, inventing a regex to
validate ids that the tools never emit, malformed loops. Clean tool calls reaching the host:
**0 of 3 tasks**.

**Hardened.** A prompt that forbids each of those by name. Still 0/3, still **0 clean calls**. Naming
the errors did not stop them.

**Few-shot.** One worked example of the exact calling convention. Still 0/3, but now **1, 3 and
9 clean calls** on the three tasks. This is the rung that matters: the API-usage confound is
gone. The model can drive the bridge. What is left is one-shot task logic with nothing to
recover from a mistake.

**Interactive self-repair.** Show the model its runtime error, its printed output and the device
state it produced. Four attempts. Still 0/3 — and greedy decoding re-emitted the **byte-identical
program** every attempt.

**Diverse self-repair.** Accumulate the history and add "do not repeat any program above."
Still 0/3, still byte-identical. Across both repair variants: **24 programs, 6 tasks, one
distinct program per task**.

That last result is the sharp one. The model was shown the exact failure and told not to repeat
itself, and it repeated itself to the byte.

## The mechanism

Tool-calling asks for one next action conditioned on a real result. That is a local decision,
and a wrong one is visible next round, in a context the model can act on.

CodeAct asks a 2B model to author an entire correct program in one shot, or to rewrite one from
a failure signal. Neither is something it can do.

So the multi-round tax is not overhead at this size. It buys the error recovery the model has no
other way to get. **The tax is the point.**

That mechanism is inference from the rung ladder, not a separate measurement. What is measured
is that removing the API confound left the score where it was, and that the repair loop produced
no new program.

## The 0.8B wall is agency, not syntax

qwen3.5-0.8B writes well-formed protocol JSON on all three tasks, and then declines to act:
`{"finish": "waiting for user input"}`, "please provide the first tool call." Every 0.8B run ends
at round 1.

The same model writes correct standalone JavaScript 50% of the time (5/10 pass@1; the 2B scores
9/10). It can write the code. It will not take the first step.

A pass@1 code benchmark cannot see this wall, because the wall is not about code.

## Instruction-following splits into a cheap half and a hard half

The research task, `aurora_brief`, is the one the 2B never passes — and its failure is not
reasoning. The facts it retrieves are right. It fails two instructions: it never writes the
source ids into its prose, and it reads only one document when the task requires two.

Adding a structured finish slot — `{"finish": "…", "cited_ids": ["<id>", …]}` — separates them.

| rung | cites sources | reads ≥2 docs | what happened |
|---|:---:|:---:|---|
| baseline | ✗ | ✗ | facts right, zero citations, one document read |
| slot | **✓** | ✗ | cited `d1, d5, d6` — including d5, which it never opened |
| slot + "cite only what you read" | **✓** | ✗ | same citations; the rule was ignored |

**Citation is a format problem, and a slot fixes it for free.** The proof that it was never a
reasoning problem is the strange row: the model cited `d5` having read only `d6`. It got `d5`'s date from a
search snippet in round 0, so it had tracked which document each fact came from the whole time —
it was just not writing that into the prose. Give it a field and it writes it down.

**"Read at least two sources" is a behavioural instruction, and no prompt we wrote moved it.**
Not the slot, not the explicit rule. The same shape shows up twice more in this work: the repair
loop that ignored "do not repeat", and a hardened tool-calling run that ignored the same. A 2B
model follows a positive schema — *put ids in this field* — and not a procedural constraint —
*do X before Y*. The honest fix is harness-side: refuse to finish until the read count is met.

The scaffold leaks no answers. Its example ids are `"<id>"` placeholders; the model only ever
sees real corpus ids in its own tool results. Both Tier-A tasks still pass under the citation
protocol, so the slot did not buy the citation at the cost of the chores.

## What this does not show

- **Two models, one family, one quantization.** qwen3.5-0.8B and 2B, int8, greedy. Whether the
  result is about phone-sized models or about CodeAct as a shape is decided by a 4B rung, and
  that rung has not been run. Until it is, read the claim as "at 0.8B–2B", which is how it is
  written above.
- **Three tasks.** Two short device chores and one document-research task.
- **Nothing here is a latency measurement.** The wall-clock in these traces includes a full model
  reload per round, because the batch driver loads once per invocation. Rounds are the honest
  cross-run unit here, not seconds.
- **Mac GPU, not the phone.** Same int8 bundles that run on device, but these runs are not
  on-device runs.

## Reproduce

The harness, the tasks, the checker and the whole control are CPU-only and need no model:

```bash
cd agent-frontier/harness && swift build -c release
./.build/release/jsprobe  selftest --tasks ../tasks                      # 20 checks
./.build/release/agentrun selftest --tasks ../tierA                      # 10 checks
./.build/release/agentrun selftest --tasks ../tierD                      #  2 checks
./.build/release/agentrun codeact-selftest --tasks ../tierA --ref-dir ../codeact
./.build/release/agentrun manifest --task ../tierA/tierA_meeting_followup.json
```

Each self-test runs a correct implementation and a do-nothing one against the same assertions.
Either landing on the wrong side is reported as a mismatch.

The last command prints the set of host functions exported into the sandbox. That set is the
permission model for a generated program: a reviewer can read exactly what a program will be
able to touch before it runs. App Store rule 2.5.2 makes `JSContext` the only way to run
generated code on iOS, so on that platform this is the whole surface.

The model runs reuse the leaderboard's deterministic eval driver over the two exported int8
bundles. Every run wrote a trace — one JSONL per run with the action, arguments, result and a
state digest for each round — and those traces, along with every program the model produced, are
in [`agent-frontier/runs/`](../agent-frontier/runs/). So each number above is checkable without a
GPU:

```bash
# tool-calling, 2B: the two device chores pass, the research task does not
grep -h '"ok"' agent-frontier/runs/phaseD_hardened2/trace_*.jsonl | tail -3

# four repair attempts, one distinct program
md5 -q agent-frontier/runs/phaseD_codeact_i/qwen3.5-2B/work_tierA_photo_album/prog_a*.js \
  | sort -u | wc -l
```

The research task's failure is in the trace in the model's own words:
`corpus.read called 1x (need 2)`.
