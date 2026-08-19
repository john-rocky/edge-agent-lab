# Model routing observations

## The Mac lane (2026-08-19, Apple FM via Catalyst — smoke tests, not table rows)

The app builds for Mac Catalyst and Apple's model is available there,
tools and vision included — so a pack's routing is now measured the day
it is written, with no phone (`ios/bench/run-mac.sh`,
[raw JSONL](../ios/bench/results/2026-08-19-mac/)). Same model family as
the phone, different machine: these numbers guide pack design and do not
enter the device table below.

After six fix rounds across one day (the failures and their fixes are
recipes now — argument names, neutral fakes, ask licenses, finder
discipline, the confirm gate, undo ownership, the noise floor), with
every pack now carrying ask_user, undo_last and — on refund / checkout /
delete — the confirm argument:

| pack | tools | cases | Apple FM (Mac) |
|---|---|---|---|
| video-editing | 18 | 40 | 34 |
| store | 18 | 44 | 31 |
| audio | 18 | 38 | 34 |
| docs | 18 | 42 | 37 |
| shopping | 12 | 34 | 23 |
| money | 11 | 30 | 20 |
| inbox | 12 | 34 | 15 |

194/262 overall. Identical builds vary by ±2–4 cases per pack between
runs — a single run ranks packs, not sentences (the noise-floor recipe).
What remains is mostly the model's character, not the packs': it grabs a
tool on no-call cases (the count is in the state; it calls the report
anyway — the same trait the device runs measured), it adds a spurious
second call far more often in Japanese than in English, it walks a
compound's steps by hand rather than calling make_reel — and, the same
instinct, walks a *change* backwards by hand rather than calling
undo_last. The confirm gate held for refund and collapsed for checkout
("Check out." arrived as confirm true — the user's words read as the
consent). inbox sits lowest: search_mail is its gravity well, pulling in
list-by-slice, read-by-number and delete-by-number alike.

# On device (2026-08-18)

Measured on iPhone (iOS 27), CPU backend, bare tool-list format, thinking
budget 32 tokens, via [toolbench](../ios/bench/README.md)
([raw JSONL](../ios/bench/results/2026-08-18/)). Four scenario packs so
far: coffee-run (6 tools), photo-editing (15 tools, then 17), focus (10
tools) and field-report (10 tools, not yet run). The bench reproduced the
hand-run demo's routing table and corrected one conclusion — see
translate below.

| pack | Apple FM | LFM2.5-1.2B int4 | LFM2.5-2.6B int4 |
|---|---|---|---|
| coffee-run, 6 tools, 20 cases | 17/20 · 3 s | 15/20 · 4.4 s | 17/20 · 15.5 s |
| photo-editing, 15 tools, 20 cases | 14/20 · 2.7 s | **16/20** · 7.2 s | 2/20 · context overflow |
| photo-editing, 17 tools, 30 cases | **24/30** · 1.8 s | 17/30 · 7 s | 0/30 · tool list alone is 1054 tokens > 1024 |
| focus, 10 tools, 20 cases | 12/20 · 1.4 s | 12/20 · 7.1 s | (8/10 EN, run cut short — rerun pending) |

Reached = every expected call made, in order, with matching arguments;
extras allowed except on no-op cases. Median per case.

| model | location | search | maps | photo OCR | translate | speak | no-op |
|---|---|---|---|---|---|---|---|
| Apple FM (on-device) | ✓ | ✓ | ✓ | ✓ | ✓* | ✓ | 0/2 |
| LFM2.5-1.2B-Instruct_int4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | 2/2 |
| LFM2.5-1.2B_int4_gpu (on CPU) | ✓ | ✓ | ✓ | ✗ | — | ✗ | — |
| LFM2.5-2.6B_int4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (EN; JA missed) | 0/2 |

\* one FoundationModels-internal error on the EN translate case.

## Per model

**Apple FM** — reached 17/20 (exact 6). Routes everything, and chains on
its own: "find a cafe" becomes get_location → search_places("cafe near
Chuo, Osaka") → open_in_maps("CAFE LA") — better than the expected single
call. The cost of that eagerness: both no-op cases grabbed a tool
(speak_out_loud for "What is 2 plus 2?", translate for the JP one).
Median 3 s per case.

**1.2B-Instruct** — reached 15/20 (exact 15). Never chains (multi-tool
cases stop after the first call) and never routes speak — "I'm sorry, but I
can't read text aloud", exactly the demo behavior. But it is the only model
that passed both no-op cases: it does not grab tools for unrelated
questions. Median 4.4 s per case.

**2.6B** — reached 17/20 (exact 14). Routes everything and chains
multi-tool cases correctly in both languages (search → maps). Over-triggers
like Apple FM: translate on both no-op cases, an unasked OCR call after
EN searches, and the JA speak case wandered to OCR. Median 15.5 s per
case — 3.5× the 1.2B, 5× Apple FM. (A first attempt at this run hit a
mid-generation engine hang; the rerun completed clean.)

## Photo-editing pack: 15 tools, and an upset

| model | reached | exact | no-op restraint | median/case |
|---|---|---|---|---|
| Apple FM | 14/20 | 13 | 0/2 | 2.7 s |
| LFM2.5-1.2B-Instruct_int4 | **16/20** | **16** | 2/2 | 7.2 s |
| LFM2.5-2.6B_int4 | 2/20 | 2 | (2/2)* | 13.5 s |

The 1.2B beats Apple FM on this pack — the first measured counterexample
to "Apple FM wins outright". How each model loses is the story:

- **Apple FM**: told "make it feel warmer", it chose the right tool and
  passed `amount: -100` — maximum *cooling*. A sign error the routing
  metric alone would have called a pass. In Japanese it stops trusting
  itself with vague amounts: 「もう少し明るくして」 gets a counter-question
  ("how much, -100 to 100?") instead of a call — three cases lost that
  way. And it still grabs a tool on both no-op cases.
- **1.2B**: discriminates all fifteen tools in English — including the
  warmth sign Apple FM got wrong — but cannot chain (it mashed two calls
  into one JSON argument), and in Japanese the enum-argument tools break:
  「右に90度回転して」 is refused in English, quoting its own enum
  ("the available rotation options are 90, 180, or 270 degrees").
- **2.6B: total collapse, and not about routing.** Its 1.55 GB of weights
  cap the context at 1024 tokens on this phone; the 15-tool list eats
  nearly all of it, generation dies mid-thought ("I need to use the"),
  and the only passes are the two no-op cases — correct by paralysis*.
  The same model scored 17/20 on the 6-tool pack. On phone RAM, a bigger
  model buys a smaller context: past some tool-list size the smaller
  model is simply the stronger agent.

## Photo-editing at 17 tools: the going-back triangle

The demo grew the pack to 17 tools (remove_background, revert_to_original
alongside undo_photo_edit) and the recording had already shown that
"undo everything" falls into undo on the 1.2B. Ten cases were added to
measure the triangle in both languages — undo the last edit, undo
everything, reset it, remove the background, cut out the person — for 30.

| model | reached | exact | no-op restraint | median/case |
|---|---|---|---|---|
| Apple FM | **24/30** | 24 | 1/2 | 1.8 s |
| LFM2.5-1.2B-Instruct_int4 | 17/30 | 17 | 2/2 | 7.0 s |
| LFM2.5-2.6B_int4 | 0/30 | 0 | — | 2 ms (rejected before generating) |

- **Apple FM owns the triangle.** All ten new cases pass in both
  languages: "Undo the last edit" → undo_photo_edit, "Undo everything /
  Reset it" → revert_to_original, "Cut out the person" →
  remove_background — the discrimination the 1.2B needed a tool-set cut
  for, it does by name. Five of its six losses are a *magnitude*:
  "more contrast", "warmer", 「もう少し明るくして」 all arrive as
  `amount: 100`, the rail. (On the 15-tool run the same Japanese wordings
  drew a counter-question instead; vague-amount handling is not stable
  run to run.) The sixth: the Japanese no-op grabbed undo_photo_edit.
- **1.2B: the same 20 as before, plus one.** On the original twenty it
  reaches 16, exactly as before; the two extra tools cost nothing there.
  On the ten new cases it reaches 1: "Undo everything" and "Reset it" both
  fall into undo_photo_edit (the well, measured on the bench now, not
  just the stage), "Undo the last edit" is *refused* — "I can't undo the
  last edit, my capabilities are limited to applying edits" — with
  undo_photo_edit in the list, and every Japanese wording of the
  triangle is refused with a recital of the tools it thinks it has. The
  stage cut (no one-step undo) remains the right recording set; the
  bench keeps the full set because the well is the measurement.
- **2.6B: the list no longer fits.** With 15 tools the prompt fitted the
  1024-token context and generation died mid-thought; with 17 the tool
  list plus instructions is 1054 tokens and every case is rejected in
  2 ms ("Input token ids are too long"). The cliff has a number now.

## Focus pack: 10 tools, and a draw

"Help me focus" as timer + notifications + brightness + notes; the axes
are the `set_` prefix neighbours, get/set brightness, remind-vs-remember
(schedule_notification vs write_note) and one two-call chain written in
call order. Apple FM and the 1.2B both reach 12/20 — by losing
completely different cases.

| model | reached | exact | chains (2) | no-op restraint | median/case |
|---|---|---|---|---|---|
| Apple FM | 12/20 | 12 | 2/2 called, 0/2 right amount | 1/2 | 1.4 s |
| LFM2.5-1.2B-Instruct_int4 | 12/20 | 12 | 0/2 | 0/2 | 7.1 s |
| LFM2.5-2.6B_int4 | 8/10 EN before the run was cut short | | 0/1 | 0/1 | 22 s |

- **Apple FM: right tool, wrong number.** "Set a timer for 25 minutes"
  → asks "what should the timer be for?" (the required `label` becomes
  a question); 「25分」 → `seconds: 150`; "one-hour focus timer" →
  `seconds: 600` in both languages. Minutes-to-seconds is a failure
  mode of its own. "Remind me to stretch in half an hour" → set_timer
  with the right 1800 s — the timer absorbs "remind me in N" — and the
  EN no-op ("how long should a pomodoro break be?") became a 25-second
  timer. 「画面を暗くして」 → 50 %, which the case scores as not dim.
  Chains are called in order every time.
- **1.2B: right number, wrong tool.** The mashed chain
  `cancel_notifications({"set_timer(label":"Focus","seconds":3600})`
  carries the correct 3600 s inside a broken call; "25 minutes" →
  15000 s (Japanese 「25分」 correct). remind-vs-remember holds up —
  schedule_notification and write_note both route in both languages —
  but *read* notes does not: "What did I ask you to remember?" →
  write_note both times. And this is the first pack where it loses its
  no-op restraint: both pomodoro questions became timers. The Japanese
  reminder call dropped a required `title` and errored at the tool.
- **2.6B, partial:** 8/10 on the English half at 22 s per case (10
  tools fit its 1024-token context with room to generate) — the chain
  stopped after cancel_notifications, the no-op grabbed a timer — then
  the app was sent to the background mid-run (see harness notes) and the
  Japanese half never ran.

## Corrected: the 1.2B translate "floor"

The demo concluded the 1.2B never routes translate — five rewrites of
prompt, description and tool name changed nothing. The bench shows it
routes translate cleanly in both languages when the text is quoted in the
request (`{"source":"good morning","to":"ja"}`). The demo beat said
"Translate **that**" — the failure was never tool selection, it was
resolving a reference to the previous answer into a tool argument. The
floor is anaphora, not routing.

Speak stays a real floor: fresh session, quoted text, either language —
the 1.2B still answers "I can't" instead of calling the tool.

## What moves routing

- The tool name is the strongest signal — stronger than the description or
  the system prompt.
- Negative system-prompt lines poison the 1.2B: "you cannot X" becomes its
  excuse to refuse, and the refusal outlives the sentence's removal.
- The bare tool list (LFM2's trained format, no OpenAI function envelope)
  cut the same six tools from 376 to 253 tokens.
- Phrasing sensitivity is real on the 1.2B: 「ここは何という街?」was
  treated as a translation request and answered without any call.

## Harness notes (learned the hard way)

- Canned tool results must cohere with the request: Apple FM saw
  "(translated text)" come back from the recording translate tool and
  retried the call twice.
- A LiteRT engine hang mid-generation blocks the transcript reader too —
  the runner writes case-start lines and aborts the model's run on a 180 s
  timeout instead of touching the transcript. That timeout was dead code
  until the evening: a `withThrowingTaskGroup` race awaits *every* child
  before it returns, even after the timer child throws, and a child
  awaiting a detached `respond` never finishes — the bench sat five
  minutes past its own deadline. The deadline is now a continuation the
  timer resumes directly; the hung work stays hung on its own thread.
- **The "hangs" were the app leaving the foreground.** Three runs froze
  ~20 s in with no error line; the fourth, with a
  `didEnterBackground` observer writing to the JSONL, showed
  `{"type":"background"}` at the exact case the silence began. A
  backgrounded app generates nothing and its timers stop with it, so
  no timeout can save it. The runner now keeps the screen awake
  (`isIdleTimerDisabled`), and the rule for a run is: nobody touches
  the phone.
- zsh ties `path` to `PATH`; a `read -r _ path` loop over an empty
  stream sets `PATH=""` and the next `tee` is "command not found". The
  orchestrating scripts avoid the name.
- One hung `devicectl` launch started the app *without its arguments*, and
  the no-`--model` fallback silently ran the newest bundle. Every run's
  JSONL records the model the process actually loaded; the script verifies
  it against what was asked.

## Numbers

LFM2.5-1.2B-Instruct_int4, CPU, cold: TTFT 1.02 s, prefill 256 tok/s,
decode 46 tok/s. Thermals are visible run to run: prefill drops to
~180 tok/s across back-to-back runs.

## Measurement asymmetry

Apple Foundation Models runs out of process; its memory use cannot be
measured from inside the app. Memory numbers, where they appear, cover the
LiteRT path only (`phys_footprint`).
