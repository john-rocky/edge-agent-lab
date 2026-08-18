# edge-agent-lab

Vague human input — text, voice, an image — turned into real app
functionality by a model that fits on the phone. No network, no cloud
fallback. This repo is three things: a showcase of what already works, the
patterns to build it with, and measurements of which model to run.

## What already works

| scenario | you say | what happens |
|---|---|---|
| [Coffee run](ios/scenarios/coffee-run/) | "Where am I?" … "Open CAFE LA in Apple Maps." | location → places search → menu OCR → Maps opens. Recorded, 4/4 tool calls on a 1.2B |
| [Photo editing](ios/scenarios/photo-editing/) | "A bit brighter." "Warmer." "Too much — undo that." | 15 editing tools; edits stack, undo works by voice. Tools + bench cases landed, recording next |
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

Measured on device, 20 JP/EN cases over the six coffee-run tools
([full table and raw JSONL](docs/model-routing.md)):

| model | routes | args | no-op restraint | median/case |
|---|---|---|---|---|
| Apple FM (on-device) | everything, chains on its own | clean | **grabs a tool anyway (0/2)** | 3 s |
| LFM2.5-1.2B-Instruct int4 | everything except speak; never chains | clean | perfect (2/2) | 4.4 s |
| LFM2.5-2.6B int4 | everything | clean | grabs a tool anyway | 13 s |

Working hypothesis: Apple's Foundation Models wins iOS tool-calling
outright — it is trained for exactly this. The table's job is the
interesting remainder: where it over-triggers, and what to run where it
does not exist (Android, custom models, unsupported devices and
languages). One correction the bench already made: the 1.2B's famous
"never routes translate" was an anaphora failure ("translate **that**"),
not a routing floor — quoted text routes cleanly.

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
