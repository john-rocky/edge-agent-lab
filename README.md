# edge-agent-lab

Vague human input — text, voice, an image — turned into correct tool calls
by a model that fits on the phone. No network, no cloud fallback.

Two working demos so far, one per platform:

- **Android screen agent** ([`android/`](android/)) — screenshot → local
  LFM2.5-VL → tap point → real tap → loop, on a Pixel 8a. 3B int4 on CPU,
  11–23 s per step. The agent is a Kotlin library
  (`//sdk:screen_agent`); the app is its host.
- **iOS tool-calling agent**
  ([lfm-tools-ios](https://github.com/john-rocky/LiteRT-Models/tree/screen-agent/lfm-tools-ios))
  — LFM2.5 behind Apple's `LanguageModel` protocol via a
  [LiteRT-LM adapter](https://github.com/john-rocky/LiteRT-LM/tree/apple-fm-guided-constrained-decoding),
  routing 54 iOS tools (location, places, photo OCR, Maps, …). Same session
  API as Apple's on-device model: swap the backend, keep the tools.

## Layout

    android/   the screen agent: app, sdk, conversion tools, findings
    ios/
      samples/ iOS sample index (the first sample lives in LiteRT-Models for now)
      bench/   on-device tool-calling benchmark (in progress)
    docs/      cross-platform findings and model routing notes

## Why a benchmark

Whether a small model routes "read this out loud" to the speak tool is not
predictable from its parameter count. Measured on device
([docs/model-routing.md](docs/model-routing.md)): LFM2.5-1.2B routes
location, search, maps and OCR, but never translate or speak — unchanged
across five prompt rewrites. The 2.6B routes all six. The benchmark turns
such one-off observations into repeatable cases: tool selection, argument
accuracy, multi-tool, no-op, JP vs EN, latency.

## Models

- [LFM2.5-1.2B-Instruct, int4 `.litertlm`](https://huggingface.co/litert-community/LFM2.5-1.2B-Instruct)
