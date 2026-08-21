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
| ⑤ | Business data — Shopify (store, POS) | filter products by stock, reprice a selection, filter orders by payment × fulfilment | **built + Commerce extension** (store: 22 tools, 54 cases — get_product, adjust_product_price, cancel_order, search_customers, create_discount added per [business-packs](business-packs.md)) |
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

## Beyond the input layer: two new routing archetypes (2026-08-20)

Everything above routes one archetype: **input-driven** — a human
utterance (text, voice, an image), plus the app's state line, goes in;
tool calls come out; the turn ends. The next axis (user, 2026-08-20) is
routes where the model is invoked on the **app's own intermediate
output**, not only on what the user typed or said:

- **Goal-driven (目標達成型)** — perceive → judge → act → perceive the
  result → judge again, looping until a goal is met. First target: an
  aesthetic polish loop — the VLM judges the photo aesthetically, picks
  the enhancement ops the judgment calls for, the app applies them, the
  VLM judges the result and decides whether to go another round and
  with which op. The polish scenario is the seed (today it is
  one-shot). New things for the bench to score: termination (stops at
  good-enough, doesn't oscillate), the judgment→op mapping, and
  iterations × cost on device. **First measured 2026-08-20** (Mac
  lane, r27–r32): the loop machinery is built — loop cases in
  scenarios/polish, perception controls in scenarios/polish-see —
  and Apple FM never stops under the open contract, edits from a
  prior ritual rather than the pixels, and answers every open quality
  question "about right" while getting the forced binary right. The
  stop and the judgment both need forced choice (one genuine stop
  once the reprompt asked yes/no), and the context window is the
  iteration budget. Canon: scenarios/polish/script.md, the
  model-routing loop paragraph, recipes "Vague judgments land on the
  rail too" / "The aesthetic prior is a gravity well".
- **Retrieval-driven (検索型)** — the input alone under-determines the
  action; the model (or the app on its behalf) first searches for or
  fetches the missing information, that context is handed to the LLM,
  and the processing is decided from input + fetched context. Distinct
  from the look-first get prefix inside the packs, which resolves
  references against mock data already on stage — here the fetch
  supplies context the input never contained. New things to score:
  recognizing that information is missing (fetch instead of invent —
  the ask_user lesson, answered by a tool instead of a human), and the
  fetch → decide → act chain.

Both stay inside this repo's frame: mock/sample-app stages, shared tool
definitions between demo and bench, and every loop iteration is itself
a routing decision the existing case format can score.

### The orchestrator thesis (user, 2026-08-20)

Where the photo thread lands after the loop rounds killed
model-as-judge: **the OS already ships the judges — the model's place
is the podium, not the bench.** iOS carries a large, free,
deterministic CV toolbox — Vision (faces, landmarks, OCR, scene
classes, segmentation, horizon, saliency), CoreImage (the edit ops,
histograms, auto-adjustment), CoreML (a CLIP index, small
regressors) — and the LLM/VLM's job is to orchestrate it: parse the
task sentence into a plan, route each clause to the cheapest layer
that answers it (metadata → embedding index → classical detector →
per-candidate VLM, in that cost order), then act. The VLM keeps only
the long-tail per-item judgments no prebuilt detector covers — always
forced-choice, always on a shortlist, never as the loop's judge or
stop. Aesthetic judgment itself: meters diagnose and stop; a scene
profile picks the targets (VNClassify vs VLM forced-choice is a
measurable A/B); an optional fine-tune line exists (Q-Align-style
discrete levels — the fixture generator doubles as a labeled-data
engine, distortion parameters are free labels). This folds the lab's
central question into the product one: the room *is* the OS's
capability list, and the recipes are its design rules. Candidate
first pack: photo-library ops — a mock library with real
Vision/CoreImage calls, a CLIP-style index, and
`check_photo(id, question, options)` — scoring the route choice
between layers: the retrieval archetype's "knowing what's missing",
with the cost gradient explicit.
**Built and first measured 2026-08-21** (Mac lane, l1–l3): the pack is
the `library` toolset — 13 tools where the cost gradient is the tool
list (find_photos / search_photos / find_photos_of_person /
find_photos_with_text / find_blurry_photos / find_duplicates /
check_photo, then open, album, favourite, a gated delete and the
rails) — over a canned camera roll of 28 photos, 52 cases in
scenarios/photo-library. **The thesis's own claim is what holds: with
no cost order stated anywhere in the instructions, 44 to 47 of 52
opening calls landed on the rung that can answer cheapest, across four
rounds and both languages.** What fails is not the choice between
layers but the slots inside one: `find_photos` carries four optional
arguments and eats every noun in the sentence — "the beach photos"
arrived as `place: "beach"` and the model told the user their library
holds none of the five it holds. Two rounds of rulings closed that:
the state names its places, a filter over a closed vocabulary refuses
rather than reports absence, and a rung that finds nothing while
another rung holds the word names *that* rung (「メイ」 went to the
picture index, which does not hold people, and came back "no photos
featuring メイ" about someone in four of them). **Answers asserting an
absence the library does not have went 5 → 1 → 3 → 0; the score went
37 → 39 → 40 → 36**, because a recovery is a second call and
`called == expected` reads it exactly as it reads a ritual tail. That
is this bench's second measured instrument limit (r45's sink was the
first) and the pack's sharpest open item. **The worst behaviour the
pack has produced came from the stage, not the bench**: its first
five-beat run answered "Yes, delete them." — with nothing selected —
by calling the finder with no arguments, selecting all 27 photos and
deleting them. A bulk destructive tool plus a finder whose emptiest
call means *everything* is a wipe waiting for a confused turn; an
argument-less finder now answers with the library's shape and selects
nothing, and delete refuses a whole-library selection. Four bench
rounds never saw it. Also open: whether `album`
belongs in a finder at all when `add_to_album` owns the word, a gate
that survives two languages (JA 「削除して」 arrives `confirm: true`,
EN calls no delete at all), and the perception rung — the mock library
is real Vision's slot, not its substitute, and the pack is written so
the swap changes no case. Canon: scenarios/photo-library/script.md.

### Video moment-seek (user, 2026-08-20) — retrieval pack candidate

Tag and index videos, then search and **seek** in natural language.
Three indexes cover what is seen, said and written: CLIP frame
embeddings at ~1 fps with timestamps (a 10-minute video indexes in
~10 s, once), the ASR transcript, OCR on keyframes — `clip` and `asr`
already live in the model repo, and the CLIP half is published as a
Core AI bundle CoreAIKit's `ImageTextEncoder` fetches by itself (spec E
in the playbook carries the graph contract). A query's clauses route to the right
index; candidate moments get VLM forced-choice verification for the
frame index's blind spots (negation, counting, action boundaries);
and the payoff is the chain into the already-built video pack:
find_moment → seek → trim → export — "ゴールの瞬間だけ切り出して".
The LLM works both sides of the index: at query time expanding a
natural phrase into CLIP-friendly prompt sets, at index time
proposing the tag vocabulary a domain needs (what to precompute for
site-inspection footage vs lectures vs screen recordings). Pure
search needs no LLM — the model earns its place at clause→index
routing, vocabulary building, and the find→edit chain. Bench shape:
canned index tools in the video room, scoring clause routing, the
timestamp copy into trim (the split-at-playhead competence, reused),
and the look-first chain; the stage demo runs real. Apple ships
consumer camera-roll moment search (iOS 18 Photos) — the edge is
search×edit, screen recordings, meetings, and business video.
**First measured 2026-08-20** (Mac lane, r33–r36): the pack is built —
`moments` toolset (the video room + search_frames / search_transcript /
search_screen_text / check_moment / seek / keep_range), a canned
soccer-match index, 40 cases in scenarios/video-moments. The pack's two
claims hold: a clause that names its modality lands on its index in
both languages, and every edit that followed a search copied the
result's times, not inventions (keep_range 440–462 out of "cut out
just the penalty"). What fails is the stop, again: a successful search
is followed by check_moment on its own result or a sweep of the other
two indexes — one JA case ran 29 search calls, the retrieval twin of
the loop's 28 rounds — and "just that one moment", with no moment ever
named, is resolved against the playhead instead of asked about (the
argument-level ask's first measured failure). Wording moved 9/40 →
17/40 and stopped; the sweep survived its A/B as character. **The stage
demo runs real** (2026-08-21): `--scenario moments` builds the index
from the loaded video with the OS's own judges — Vision classify + OCR
on ≤90 frames, the on-device recognizer on the audio — and the recorded
take walks the whole chain: "find the moment they say goal" →
search_transcript hits the commentator's line → keep_range cuts 40 s to
2 s → export. Fully offline, no models beyond the OS and Apple FM; the
CLIP rung is what's left. Canon: scenarios/video-moments/script.md.

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
