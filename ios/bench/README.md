# toolbench — on-device tool-calling benchmark (iOS)

Does a small model call the right tool, with the right arguments, given a
vague human request? Measured on the phone, against the real tool schemas,
with zero side effects.

## How it works

The runner lives inside the lfm-tools-ios app
([LiteRT-Models](https://github.com/john-rocky/LiteRT-Models/tree/screen-agent/lfm-tools-ios),
`Sources/Bench/`). `--toolbench` launches it:

1. Every tool is wrapped in a `RecordingTool` — real name, description and
   argument schema, but `call` returns a canned result. Routing and guided
   decoding run unchanged; nothing prompts, speaks or switches apps.
2. Each case gets a fresh session. The calls the model made are read back
   from the session transcript.
3. Results stream to `Documents/toolbench-<timestamp>.jsonl`, one case per
   line, a `summary` line last. Per-run filenames on purpose: `devicectl
   copy from` returns stale cached content for a path it has copied before.

One model per app launch (`--model apple` for Apple's on-device model, any
filename substring for a LiteRT bundle). [`run-device.sh`](run-device.sh)
loops the models and pulls the JSONL back.

## Case format

```json
{ "id": "en-translate-1",
  "input": "Translate 'good morning' to Japanese.",
  "lang": "en",
  "expected": [
    { "tool": "translate",
      "args": { "source": { "contains": "good morning" },
                "to": { "equals": "ja" } } }
  ] }
```

- `expected` is the exact call sequence; `[]` means a correct run calls
  nothing — a model that grabs a tool anyway fails the case.
- Matchers: `equals`, `contains` (both case-insensitive),
  `{"number": n, "tol": t}`, `{"dateResolvesTo": "tomorrow"}`.
- `args` omitted means the call's arguments are not scored. The JP search
  cases use this deliberately: a Japanese request may legitimately produce a
  Japanese or an English query string, and both are right.
- `image` is reserved for the VLM stage.

[`cases/core-20.json`](cases/core-20.json): 10 EN + 10 JP over the six demo
tools, one no-op each.

## What a JSONL line records

`case, lang, model, input, expected, called, calls (raw args), selectionPass
(called sequence == expected), argsPass (all matchers), pass, ms, answer,
error`.

## Known asymmetry

Apple Foundation Models runs out of process; its memory cannot be measured
from the app. Memory numbers, when added, will cover the LiteRT path only.
