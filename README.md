# edge-agent-lab

Vague human input — text, voice, an image — turned into real app
functionality by a model that fits on the phone. No network, no cloud
fallback. This repo is three things: a showcase of what already works, the
patterns to build it with, and measurements of which model to run.

## What already works

| scenario | you say | what happens |
|---|---|---|
| [Coffee run](ios/scenarios/coffee-run/) | "Where am I?" … "Open CAFE LA in Apple Maps." | location → places search → menu OCR → Maps opens. Recorded, 4/4 tool calls on a 1.2B |
| [Photo editing](ios/scenarios/photo-editing/) | "A bit brighter." "Warmer." "Undo everything." "Remove the background." | 17 editing tools; edits stack, a whole chain reverts by voice, the subject lifts off the background. Benched on 3 models, recorded |
| [Focus](ios/scenarios/focus/) | "Dim the screen — I need to focus." "Silence my notifications and set a one-hour timer." | one sentence fans out into notifications + timer + brightness. Pack built; bench and recording next |
| [Android screen agent](android/) | "open the notification history" | screenshot → local VLM → tap point → real tap → loop, on a Pixel 8a |

Each iOS scenario is a **pack**: a tool set, a demo script, and benchmark
cases that grow the model table below at the same time. The app hosting
them is
[lfm-tools-ios](https://github.com/john-rocky/LiteRT-Models/tree/screen-agent/lfm-tools-ios)
— LFM2.5 behind Apple's `LanguageModel` protocol via a
[LiteRT-LM adapter](https://github.com/john-rocky/LiteRT-LM/tree/apple-fm-guided-constrained-decoding),
so the same session runs Apple's model or an open one: swap the backend,
keep the tools.

## Which model to run

Measured on device, 20 JP/EN cases per scenario pack
([full tables and raw JSONL](docs/model-routing.md)). Reached = expected
calls made, with correct arguments:

| pack | Apple FM | LFM2.5-1.2B int4 | LFM2.5-2.6B int4 |
|---|---|---|---|
| Coffee run (6 tools) | **17/20**, 3 s/case | 15/20, 4.4 s | 17/20, 15.5 s |
| Photo editing (15 tools) | 14/20, 2.7 s | **16/20**, 7.2 s | 2/20 — context overflow |

Working hypothesis: Apple's Foundation Models wins iOS tool-calling
outright — it is trained for exactly this. The measurements keep
sharpening it: Apple FM is 2–5× faster and routes everything, but it
grabs a tool on requests that need none, got a signed argument backwards
("warmer" → amount -100), and in Japanese asks how much instead of
deciding. The 1.2B never chains but never over-triggers — and beat
Apple FM on the 15-tool pack. The 2.6B's weights cap its context at
1024 tokens, and 15 tool schemas don't fit: on phone RAM, the bigger
model can be the weaker agent.

## Layout

    ios/
      scenarios/   scenario packs: cases.json + script.md per scenario
      bench/       toolbench — runner scripts, report.py, results/
      samples/     sample index (the app lives in LiteRT-Models for now)
    android/       the screen agent: app, sdk, conversion tools, findings
    docs/          model routing, roadmap, findings

[Roadmap](docs/ROADMAP.md): scenarios lead, the bench follows.

## Models

- [LFM2.5-1.2B-Instruct, int4 `.litertlm`](https://huggingface.co/litert-community/LFM2.5-1.2B-Instruct)
