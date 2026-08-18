# Model routing observations (2026-08-18, on device)

Measured on iPhone (iOS 27), the lfm-tools-ios demo set (6 tools), CPU
backend, bare tool-list format, thinking budget 32 tokens. Hand-run beats,
not yet harness output — the benchmark's first job is to reproduce this
table.

| model | location | search | maps | photo OCR | translate | speak |
|---|---|---|---|---|---|---|
| LFM2.5-1.2B-Instruct_int4 | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ |
| LFM2.5-1.2B_int4_gpu (on CPU) | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| LFM2.5-2.6B_int4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

- Translate/speak on the 1.2B is not a prompting problem. Five iterations
  of prompt, tool description and tool name (`speak` → `speak_out_loud`)
  changed nothing: the model translates by itself and apologizes that it
  "can't speak out loud". Capability floor.
- The two 1.2B checkpoints differ on photo OCR — same size, different
  training.
- The 2.6B routes 6/6 but reasons in a hidden `<think>` channel (a thinking
  token budget is required to bound it) and is noticeably slower per turn.

## What moves routing

- The tool name is the strongest signal — stronger than the description or
  the system prompt.
- Negative system-prompt lines poison the 1.2B: "you cannot X" becomes its
  excuse to refuse, and the refusal outlives the sentence's removal.
- The bare tool list (LFM2's trained format, no OpenAI function envelope)
  cut the same six tools from 376 to 253 tokens.

## Numbers

LFM2.5-1.2B-Instruct_int4, CPU, cold: TTFT 1.02 s, prefill 256 tok/s,
decode 46 tok/s. Thermals are visible run to run: prefill drops to
~180 tok/s across back-to-back runs.

## Measurement asymmetry

Apple Foundation Models runs out of process; its memory use cannot be
measured from inside the app. Memory numbers, where they appear, cover the
LiteRT path only (`phys_footprint`).
