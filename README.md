# edge-agent-lab

I'm testing whether a model small enough for a phone can turn plain speech, text or a photo into calls to an app's functions, with no cloud model behind it. This repo has the scenarios I've built so far and the measurements comparing the models.

For example, in the coffee-run demo you say "Where am I?", "Find a coffee shop near me.", "Read the text in my latest photo." and "Open CAFE LA in Apple Maps." The phone finds its location, searches for places, reads the menu with OCR and opens Maps. A 1.2B model made all 4 tool calls correctly in that run, and got 15 of [the 20 test cases](#which-model-to-run) right.

## Scenarios

| Scenario | You say | What happens |
|---|---|---|
| [Coffee run](ios/scenarios/coffee-run/) | "Where am I?" … "Open CAFE LA in Apple Maps." | Location, places search, menu OCR, then Maps |
| [Photo editing](ios/scenarios/photo-editing/) | "Make the photo a bit brighter." "A bit warmer, too." "Undo everything — back to the original." "Remove the background." | Edits stack, and one sentence reverts the whole chain. The app has 17 editing tools. The recorded run used the 1.2B with the one-step undo tool removed |
| [Focus](ios/scenarios/focus/) | "Dim the screen — I need to focus." "Silence all my notifications and set a one-hour focus timer." | Benchmarked, not recorded yet. Both models call `set_brightness` for the first sentence. The last sentence needs two calls (cancel the notifications, set the timer): Apple's model makes both but sets 600 s, and the 1.2B makes one broken call |
| [Android screen agent](android/) | "open the notification history" | Takes a screenshot, asks a local vision model where to tap, then taps. It runs on a Pixel 8a |

[More scenarios](docs/scenarios.md) cover video editing, a store admin, an audio mixer and documents. The [roadmap](docs/ROADMAP.md) has what I plan next.

## Try it

- **iPhone:** [lfm-tools-ios](https://github.com/john-rocky/LiteRT-Models/tree/screen-agent/lfm-tools-ios) is the app that runs these scenarios. It runs Apple's model or LFM2.5 through Apple's `LanguageModel` protocol, so you can change the model and keep the tools.
- **Android:** [the screen agent app](android/app/README.md).
- **A Mac, with no phone:** you can build the test harness behind [one tool call at a time](#why-one-tool-call-at-a-time) and run its self-test in about ten seconds. The self-test runs no model. Its last line starts with `CODEACT SELFTEST: PASS`.

```bash
cd agent-frontier/harness && swift build -c release
./.build/release/agentrun codeact-selftest --tasks ../tierA --ref-dir ../codeact
```

## Which model to run

No model won every scenario. I measured each one on an iPhone with 20 Japanese and English cases ([full tables and raw results](docs/model-routing.md)). A case counts when the model made every expected call, in order, with matching arguments. Extra calls are allowed, except where no call was expected:

| Scenario | Apple's Foundation Models | LFM2.5-1.2B int4 | LFM2.5-2.6B int4 |
|---|---|---|---|
| Coffee run (6 tools) | 17/20, 3 s per case | 15/20, 4.4 s | 17/20, 15.5 s |
| Photo editing (15 tools) | 14/20, 2.7 s | 16/20, 7.2 s | 2/20, context overflow |
| Focus (10 tools) | 12/20, 1.4 s | 12/20, 7.1 s | 8/10 in English, run cut short |

Apple's model was 1.5 to 5 times faster, but it often got numbers wrong: "warmer" became an amount of -100, and "one-hour timer" became 600 s. The 1.2B usually got the numbers right but sometimes called the wrong tool. The app caps the 2.6B at 1,024 tokens of context, because iOS kills the process at 2,048, so 15 tool schemas left it almost no room to answer.

The photo-editing app now has 17 tools. With those and 30 cases, Apple's model got 24 right, the 1.2B 17, and the 2.6B none, because the tool list and instructions no longer fit.

## Why one tool call at a time

I measured whether a small model does better writing one program that calls the tools or making one tool call per step. At 2B, the whole-program approach solved 0 of 3 tasks and the step-by-step approach solved 2 of 3 ([the note](docs/codeact-vs-tool-calling.md)), so the scenarios here make one tool call per step.

## Layout

    ios/
      scenarios/    one folder per scenario, usually cases.json and script.md
      bench/        the benchmark runner scripts, report.py and results
      samples/      sample index
    android/        the screen agent: app, SDK, conversion tools and findings
    agent-frontier/ the test of whole programs versus one call per step
    docs/           model routing, roadmap and findings

## Models

- [LFM2.5-1.2B-Instruct, int4 `.litertlm`](https://huggingface.co/litert-community/LFM2.5-1.2B-Instruct)
