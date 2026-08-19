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
| ② | Video editing — CapCut / LumaFusion | trim, split, speed, crop to 9:16, captions, fade, stabilise, export | **built** (video-editing: 12 tools, 6 beats, 30 cases); first run on Apple FM when the phone is back |
| ③ | Audio / timeline — GarageBand | track volume, pan, duplicate, fade, effects, loops | **built** (audio: 15 tools, 6 beats, 32 cases; four synthesized tracks through AVAudioEngine) |
| ④ | Documents — Acrobat / Goodnotes | delete / reorder pages, annotate, remove highlights, sign, convert | **built** (docs: 12 tools, 7 beats, 30 cases; a real PDF through PDFKit) |
| ⑤ | Business data — Shopify (store, POS) | filter products by stock, reprice a selection, filter orders by payment × fulfilment | **built** (store: 14 tools, 7 beats, 34 cases with state); first run on Apple FM when the phone is back |

All five are built (2026-08-19); none of ②–⑤ has run on the phone yet —
each pack's script.md says what to read in run.log on the first run.

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

## Later

The same cases on Android — the case format is platform-independent on
purpose; one scenario, one table, two platforms.

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
