# Roadmap

The repo has three jobs, in this order:

1. **Show what is possible** — scenarios: vague human input becoming real
   app functionality, on device, with a recording.
2. **Show how to build it** — recipes: how to write tools a small model
   can route, how to resolve "that" into an argument, how to keep a model
   from grabbing tools it shouldn't.
3. **Show what to run it on** — the model table: measured, per scenario.
   The working hypothesis is that Apple's Foundation Models wins
   tool-calling on iOS outright — it is trained for exactly this. The
   interesting question the table answers is *where it doesn't reach*:
   Android, custom models, devices and languages without Apple
   Intelligence, and the failure modes the runs keep exposing (it grabs
   a tool on requests that need none; its numbers are wrong more often
   than its tools).

The unit of growth is a **scenario pack**: one directory holding a tool
set, a demo script, bench cases, and a recording. Adding a pack grows the
showcase and the benchmark at the same time — the bench never grows on
its own.

## Where packs come from: market-in

Not "we have tool calling — what shall we let it operate?" but "here is
an app millions already use, with a hundred features behind a deep
touch UI — is calling those features in plain words worth something?"
The first cut of packs (focus, briefing, sensors, handoff, chains,
compound) answered the first question: they show chaining and compound
calls well, and they read as AI-invented uses of AI. They stay as
capability showcases; they are not the growth axis. The growth axis is
existing app categories, and it looks like this:

| # | app type (the real ones) | what a pack calls | status |
|---|---|---|---|
| ① | Image editing — Lightroom / Canva | adjust, crop, filter, cut out, save; the photo alone as input | **done**: photo-editing, vision, polish |
| ② | Video editing — CapCut / LumaFusion | trim, split, speed, crop to 9:16, captions, fade, stabilise, music, export; make_reel as the one-call compound | **built** (video-editing: 18 tools incl. auto_captions, 40 cases) |
| ③ | Audio / timeline — GarageBand | track volume, pan, duplicate, fade, effects, loops | **built** (audio: 18 tools, 38 cases; four synthesized tracks through AVAudioEngine) |
| ④ | Documents — Acrobat / Goodnotes | delete / reorder pages, annotate, remove highlights, sign, watermark, extract | **built** (docs: 18 tools incl. form filling and redaction, 42 cases; a real PDF through PDFKit) |
| ⑤ | Business data — Shopify (store, POS) | filter products by stock, reprice a selection, filter orders by payment × fulfilment | **built** (store: 18 tools, 44 cases) |
| ⑥ | Shopping — the buyer's side (Amazon) | search, sort, "the second one" → cart, coupon, checkout, track | **built** (shopping: 12 tools, 34 cases) |
| ⑦ | Personal finance — Money Forward | filter / search transactions, categorize the selection, budgets, reports, find subscriptions | **built** (money: 11 tools, 30 cases) |
| ⑧ | Mail triage — Spark / Gmail | list / search → archive, snooze, flag; a reply drafted, never sent | **built** (inbox: 12 tools, 34 cases; all data canned) |
| ⑨ | CRM — Salesforce / HubSpot | search opportunities by owner/stage/amount/close date, stage updates, follow-up tasks | **built** (crm: 12 tools, 36 cases; frozen today in the state makes relative dates scorable — spec in [business-packs](business-packs.md)) |
| ⑩ | Project management — Jira / Asana / Linear | search issues, assign, status/priority/due-date changes, close | **built** (pm: 11 tools, 36 cases; the change_* family and close-vs-status are the planted similar-tool axes) |
| ⑪ | ERP / Accounting — SAP / NetSuite / QuickBooks | invoices (search, mark paid), inventory, expenses, orders | **spec'd**, P1 (money covers the expense corner) |
| ⑫ | HCM / HR — Workday | employees, leave requests (approve/reject), shifts | **spec'd**, P1 |
| ⑬ | Collaboration — Slack / Teams | search messages, reply, reactions, channels | **spec'd**, P2 (inbox covers the mail half) |

All eight are built (2026-08-19), and none has run on the phone yet — but
routing no longer waits for the phone: the app builds for Mac Catalyst
(Apple FM is available on the Mac, tools and vision included), so every
pack's cases run there first (`ios/bench/run-mac.sh`). The Mac runs are
smoke tests — the model table stays device-measured — and they already
paid for themselves: eleven routing bugs found and fixed before any
recording (see the git log around 2026-08-19). What still needs the
device: real effects (pixels, speaker, permissions, AlarmKit), timing,
and every number that goes in the table.

Why these and in this order:

- ② is the natural step after images, and the model does not have to
  understand video: the app hands it the playhead, the selected clip and
  the frame size, and "cut the first two seconds, make it vertical, fade
  out at the end" is `trim → crop → fade` — three calls replacing a
  minute of thumb work. **State in, tools out** is the pattern.
- ⑤ is a different kind of agent: natural language → search → filter →
  update existing records → a business step. Every pack so far
  shortcuts an editor's UI; this one operates data. Inputs are tiny, so
  a local model is in reach — and the bench gets a second class of
  case (query correctness, not edit correctness).
- ③ and ④ measure new argument shapes (tracks and time ranges; pages and
  annotation types) without repeating ①.
- Files / OS-level operations are not a category: nobody's daily app is
  "the file system". Calendar and reminders are real but native and
  commonplace — they stay inside packs as supporting tools, not as packs.

Each pack is a *stand-in* for the app category: the tool set mirrors the
real app's feature list and argument shapes (the names the app's own menus
use), the demo runs on a working reimplementation of enough of it to make
the calls visible, and the recording's claim is "this is what your app's
menu would sound like".

## Inputs (cross-cutting, built)

- **Text** — typed or scripted beats.
- **Voice** — SpeechAnalyzer streams the mic into the same send path;
  the stage's `--voice` takes each beat from the air.
- **Image, natively** — the photo goes in as an `Attachment`, the model
  looks and decides, tools take an `ImageReference` and resolve it
  against the transcript. A photo with no words means "make it look its
  best" (polish). The case format's `image` field names a fixture the
  runner attaches, so this routes on the bench too.
- For ② and ③, **app state** is an input in its own right: playhead,
  selection, sizes, track list — passed by the app, never guessed by the
  model. Built for ②–⑤: the state line opens every message on the stage
  and every case on the bench (`state` in cases.json), and the model is
  told what its own calls did before it is asked for the next one. Each
  pack's state names what the words will refer to — clips and the
  playhead, the selection, tracks and their levels, pages by their first
  line — so "their", "the keys", "the cover" are resolved by the app.

## The business wing (2026-08-20)

⑨–⑬ turn the repo into an **on-device tool-calling benchmark for real
app categories** — full spec in [business-packs.md](business-packs.md).
The decisions that shape it (user, 2026-08-20): integration stays
**mock-only** (no real Salesforce/Shopify/SAP/Jira APIs, no DB, no
auth), but **every category gets a minimal sample app** — fixture rows
on screen, a language input, the model's tool call shown verbatim, and
the visible data changing when the mock tool runs — so the value of
tool calling is judged by eye as well as by score. Benchmark and sample
app share one tool implementation (already this repo's architecture;
store ≈ the Commerce pack's admin half). Beyond per-pack cases, the
spec adds an evaluation program the current bench doesn't have yet:
tool-count scaling (5→35→70), cross-domain routing over merged packs,
tool-definition A/B on the same case set, and failure records complete
enough to analyze across configs.

That program is in service of **the bench's central research question:
how many tool specs, under what names, with what descriptions, can a
small on-device LM carry and stay stable?** Everything the bench
measures folds back into that one prescription — the recipes are its
qualitative half (names beat descriptions beat instructions; contracts
live at the tool boundary), the scaling and A/B runs are its
quantitative half, and the deliverable is the number-and-wording
envelope an app developer can hand their tools to a small model inside.

## Later

The same cases on Android — the case format is platform-independent on
purpose; one scenario, one table, two platforms.

## Three tools every pack carries (2026-08-19)

- **`ask_user`** — asking is routable: when a required detail is truly
  absent, the model calls a tool instead of inventing (measured: left to
  prose it invents, especially in Japanese). The ask-back cases score it.
- **`undo_last`** — every box keeps value snapshots; "やっぱりやめて"
  works everywhere, and where a full revert also exists the going-back
  triangle the photo pack measured is re-armed on purpose.
- **The confirm gate** — destructive tools (refund, checkout, delete)
  take `confirm`, to be left false until the user has said yes; the app
  answers a false call with what would happen, the state carries
  "Awaiting confirmation: …", and the yes-turn is a case of its own.

## Standing rails (grow with every pack, never ahead of one)

- **Try it on Apple's model first.** A new capability is shown the day
  it works on Apple FM (`--backend apple` on the stage, `--model apple`
  in the chat, `--voice` for spoken beats); that is a minute per pack,
  not a quarter of an hour.
- The bench follows interest, not the calendar: a pack gets its cases
  and its three-model run when someone bites on the demo. Benching every
  pack up front is time spent on examples that may be thrown away.
- Pack cases merge into the bench; the model table gets a row/column.
- Recipes are extracted from what the pack taught, into docs/.
- New models are added when a scenario needs them, not for coverage.

## Out of scope

General GUI agents (the Android screen agent stays its own track), cloud
routing, long-context understanding, and file-system agents.
