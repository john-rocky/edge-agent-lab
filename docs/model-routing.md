# Model routing observations (2026-08-18, on device)

Measured on iPhone (iOS 27), the lfm-tools-ios demo set (6 tools), CPU
backend, bare tool-list format, thinking budget 32 tokens. Two sources: the
hand-run stage demo, and the first
[toolbench](../ios/bench/README.md) run over 20 JP/EN cases
([raw JSONL](../ios/bench/results/2026-08-18/)). The bench reproduced the
demo's routing table and corrected one conclusion — see translate below.

| model | location | search | maps | photo OCR | translate | speak | no-op |
|---|---|---|---|---|---|---|---|
| Apple FM (on-device) | ✓ | ✓ | ✓ | ✓ | ✓* | ✓ | 0/2 |
| LFM2.5-1.2B-Instruct_int4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | 2/2 |
| LFM2.5-1.2B_int4_gpu (on CPU) | ✓ | ✓ | ✓ | ✗ | — | ✗ | — |
| LFM2.5-2.6B_int4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 0/2 |

\* one FoundationModels-internal error on the EN translate case.

## Per model

**Apple FM** — reached 17/20 (exact 6). Routes everything, and chains on
its own: "find a cafe" becomes get_location → search_places("cafe near
Chuo, Osaka") → open_in_maps("CAFE LA") — better than the expected single
call. The cost of that eagerness: both no-op cases grabbed a tool
(speak_out_loud for "What is 2 plus 2?", translate for the JP one).
Median 3 s per case.

**1.2B-Instruct** — reached 15/20 (exact 15). Never chains (multi-tool
cases stop after the first call) and never routes speak — "I'm sorry, but I
can't read text aloud", exactly the demo behavior. But it is the only model
that passed both no-op cases: it does not grab tools for unrelated
questions. Median 4.4 s per case.

**2.6B** — 14 cases before an engine hang cut the run (numbers from the
partial). Routes everything including speak and translate; over-triggers
like Apple FM (translate on the EN no-op, an unasked OCR call after
search). ~13 s per case — 3× the 1.2B.

## Corrected: the 1.2B translate "floor"

The demo concluded the 1.2B never routes translate — five rewrites of
prompt, description and tool name changed nothing. The bench shows it
routes translate cleanly in both languages when the text is quoted in the
request (`{"source":"good morning","to":"ja"}`). The demo beat said
"Translate **that**" — the failure was never tool selection, it was
resolving a reference to the previous answer into a tool argument. The
floor is anaphora, not routing.

Speak stays a real floor: fresh session, quoted text, either language —
the 1.2B still answers "I can't" instead of calling the tool.

## What moves routing

- The tool name is the strongest signal — stronger than the description or
  the system prompt.
- Negative system-prompt lines poison the 1.2B: "you cannot X" becomes its
  excuse to refuse, and the refusal outlives the sentence's removal.
- The bare tool list (LFM2's trained format, no OpenAI function envelope)
  cut the same six tools from 376 to 253 tokens.
- Phrasing sensitivity is real on the 1.2B: 「ここは何という街?」was
  treated as a translation request and answered without any call.

## Harness notes (learned the hard way)

- Canned tool results must cohere with the request: Apple FM saw
  "(translated text)" come back from the recording translate tool and
  retried the call twice.
- A LiteRT engine hang mid-generation blocks the transcript reader too —
  the runner writes case-start lines and aborts the model's run on a 180 s
  timeout instead of touching the transcript.
- One hung `devicectl` launch started the app *without its arguments*, and
  the no-`--model` fallback silently ran the newest bundle. Every run's
  JSONL records the model the process actually loaded; the script verifies
  it against what was asked.

## Numbers

LFM2.5-1.2B-Instruct_int4, CPU, cold: TTFT 1.02 s, prefill 256 tok/s,
decode 46 tok/s. Thermals are visible run to run: prefill drops to
~180 tok/s across back-to-back runs.

## Measurement asymmetry

Apple Foundation Models runs out of process; its memory use cannot be
measured from inside the app. Memory numbers, where they appear, cover the
LiteRT path only (`phys_footprint`).
