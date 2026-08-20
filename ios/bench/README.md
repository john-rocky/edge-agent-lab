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
SCENARIO=audio ./run-device.sh             # audio pack (state cases)
SCENARIO=docs ./run-device.sh              # documents pack (state cases)
./run-mac.sh video-editing store audio docs shopping money inbox   # no phone
```

## The Mac lane

The same runner builds for Mac Catalyst (`LFMToolsMac` — no LiteRT engine
in that build; Apple's model is the backend, and Foundation Models is
available on Apple-Intelligence Macs, vision included). `run-mac.sh`
pushes a pack's cases into the app's file home
(`~/Library/Application Support/LFMTools`), launches the app headless,
pulls the JSONL into `results/<date>-mac/`, and prints the fails. This is
how a pack's routing gets verified the day it is written, with no phone.
The Mac runs are smoke tests; the model table stays device-measured.

Two flag pairs serve the business wing's evaluation program.
`--instructions <pack>` pins the instructions independently of
`--toolset`, so the cross-domain runs (`business-crm` etc.) grow the
tool list while each pack's cases keep their measured instructions.
`--only <name,name,…>` cuts the toolset down to the named tools, list
order preserved — the tool-count ladder. A five-tool subset cannot
hold a whole pack, so [ladder.json](ladder.json) cuts each low rung
into "mini-app" groups and [ladder.py](ladder.py) assigns every case
to the one group holding its correct tools (first group in file order
that covers the case's expected calls; a subset without the case's
answer measures nothing). `./run-mac.sh ladder-crm5a` runs one group;
`ladder.py check` proves every rung is a partition.

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
- `expectAsk: true` marks an ask-back case: the input deliberately omits a
  required argument ("Add a caption." — saying what?). A correct run calls
  `ask_user` (asking is routable — every state pack carries the tool) and
  nothing else, or calls nothing and asks in prose (a question mark in the
  answer). The JSONL line records `asked`.
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
written. `video-editing`: 20 + 20 over 18 tools where `state` starts
working — "split it at the playhead" is scored against the playhead number
in the state block, "make the second clip slow motion" is one call whose
`clip` argument names the clip, and "how long is the video?" expects no
call: the answer is in the state. `store`: 22 + 22 over 18 tools — the first pack that operates
records: the finders (search by name / filter by field / low stock /
orders by payment × fulfilment) are scored on their query arguments, the
bulk actions on acting without re-searching (the `state` carries the
selection), and update_price vs set_price is the signed-percent-vs-amount
axis. `audio`: 19 + 19 over 18 tools — levels read from the state and
moved ("a bit quieter" accepts 43–67 from a 70), tracks named by what the
user calls them (`contains`), booleans for mute / solo scored as
"true" / "false", two chains. `docs`: 21 + 21 over 18 tools — page numbers
read from a state that names pages by their first line ("the cover" → 1,
"the last page" → 6), the this_page / all_pages scope, a go_to → sign
chain; the JA search query is left unscored (「敷金」 or "deposit" are both
right). `shopping` (17 + 17 over 12 tools) / `money` (15 + 15 over 11) /
`inbox` (17 + 17 over 12) — the buyer's numbered-results axis ("the
second one" is a number in the state), the filter→categorize and
find→archive chains, one ask-back per language per pack, and the two
newest axes every pack now carries: **undo_last** (「やっぱりやめて」 —
where a full revert also exists this re-arms the going-back triangle the
photo pack measured) and the **confirm gate** (refund / checkout /
delete take `confirm`, to be left false until the user has said yes; the
pair of cases per pack measures both directions — not confirming
unasked, and turning "Yes, go ahead." plus the state's "Awaiting
confirmation" line into confirm true with the right number).

## What a JSONL line records

`case, lang, model, toolset, tools (list size), input, expected, called,
calls (raw args), selectionPass (called sequence == expected), argsPass
(all matchers), pass, ms, answer, error`. The run's opening line records
the run `date` — what lets `report.py` resolve `dateResolvesTo` matchers
offline; "tomorrow" only means something relative to the day the run
happened — and `toolNames`, the full list the model saw, so a row's
tool-list identity survives into cross-config analysis.

## Known asymmetry

Apple Foundation Models runs out of process; its memory cannot be measured
from the app. Memory numbers, when added, will cover the LiteRT path only.
