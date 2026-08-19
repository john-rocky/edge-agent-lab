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
filename substring for a LiteRT bundle), one scenario pack per run
(`--toolset demo|photo` picks the tool set the model sees).
[`run-device.sh`](run-device.sh) loops the models, pushes the scenario's
cases, and pulls the JSONL back:

```sh
./run-device.sh                            # coffee-run pack, three models
SCENARIO=photo-editing ./run-device.sh     # photo pack
SCENARIO=video-editing ./run-device.sh     # video pack (state cases)
SCENARIO=store ./run-device.sh             # store pack (state cases)
```

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
- `image` names a fixture image the runner attaches to the prompt (the
  vision packs).
- `state` is the app state a message opens with, verbatim, for the packs
  where state is the input (video-editing): the runner sends
  `[App state] <state>` ahead of `input`, exactly as the stage does, and
  the session gets that pack's instructions. Cases that name a playhead or
  a clip edge are only scorable against it.

Cases live with their scenario pack in
[`../scenarios/`](../scenarios/) — each pack is a cases.json, the demo
script, and the in-app tool set it was written against. `coffee-run`:
10 EN + 10 JP over the six demo tools. `photo-editing`: 15 + 15 over the
17 editing tools, where `number±tol` starts earning its keep ("a bit
brighter" accepts amount 5–55; "half size" accepts 45–55) and the
undo / revert_to_original / remove_background triangle probes similar-tool
gravity wells the demo recording already fell into once. `focus`: 10 + 10
over 10 device-control tools — the `set_` prefix neighbors
(timer/brightness/torch), the get/set brightness pair, remind-vs-remember
(schedule_notification vs write_note), and a two-call chain written in
call order. `field-report`: 10 + 10 over 10 tools where `dateResolvesTo`
starts working — "tomorrow at 9" is a date no model knows from weights,
so the honest route is get_current_time first, scored as a reasonable
extra. In this pack get_current_time is the one bench tool that is *not*
canned: the matcher resolves "tomorrow" against the device clock at run
time, and a canned today would break the cases the day after it was
written. `video-editing`: 15 + 15 over 12 tools where `state` starts
working — "split it at the playhead" is scored against the playhead number
in the state block, "make the second clip slow motion" is a select → speed
chain, and "how long is the video?" expects no call: the answer is in the
state. `store`: 17 + 17 over 14 tools — the first pack that operates
records: the finders (search by name / filter by field / low stock /
orders by payment × fulfilment) are scored on their query arguments, the
bulk actions on acting without re-searching (the `state` carries the
selection), and update_price vs set_price is the signed-percent-vs-amount
axis.

## What a JSONL line records

`case, lang, model, input, expected, called, calls (raw args), selectionPass
(called sequence == expected), argsPass (all matchers), pass, ms, answer,
error`. The run's opening line also records the run `date`, which is what
lets `report.py` resolve `dateResolvesTo` matchers offline — "tomorrow"
only means something relative to the day the run happened.

## Known asymmetry

Apple Foundation Models runs out of process; its memory cannot be measured
from the app. Memory numbers, when added, will cover the LiteRT path only.
