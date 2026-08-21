# Video moment-seek — search the video, then edit what you found

The retrieval archetype's first pack (ROADMAP "Video moment-seek"): the
video room plus three indexes over what a video contains — what is **seen**
(frame embeddings), what is **said** (the transcript), what is **written**
(text on screen) — and the payoff chain into the already-built editor:
find → seek → keep_range → export. 「ゴールの瞬間だけ切り出して」is the
pack in one sentence. The input alone under-determines the action: the
times the edit needs exist only in the index, so the model must fetch
before it acts — and a model that invents a timestamp instead of searching
fails on args, which is the archetype's failure mode made scorable.

Tools: `ToolBox.moments`, 24 — the video pack's 18 plus six
(`Tools/VideoEditTools.swift`, "The moment index"):

- `search_frames(query)` / `search_transcript(query)` /
  `search_screen_text(query)` — the three indexes. The routing thesis in
  tool form: a clause names its index ("where he *says*…" / "where the
  scoreboard *shows*…" / "where the goal *happens*"), and the choice is
  scored, not the search internals.
- `check_moment(seconds, question, options)` — the per-candidate VLM look,
  forced-choice on the argument (the judge-study ruling: enumerate the
  answers, force one).
- `seek(seconds)` — move the playhead and show that frame. Navigation, not
  an edit: nothing to undo.
- `keep_range(start_seconds, end_seconds)` — keep only that span, cut the
  rest. The moment-to-edit bridge; trim_clip keeps the edge cuts.

Bench: **canned index** (`Bench/RecordingTool.swift`, `MomentEcho`) — one
frozen 600 s soccer-match recording, three indexes over the same match, so
the clause→index choice is scorable and the searches echo real-shaped
moments ("214–226 s — a goal — a header — and the celebration"). Row
keywords carry the JA the cases utter (recipes: canned data must be
findable in every language).

Stage: **the index is real** (built 2026-08-21, `MomentIndexBox`) — the
orchestrator thesis's cheapest rungs, no extra models: ≤90 source frames
through VNClassifyImageRequest + VNRecognizeTextRequest, the audio track
through the on-device recognizer auto_captions already used; check_moment
runs the same two requests on the one frame it is asked about. A CLIP
rung slots in above the classifier when the model repo's embedding build
lands — today "find the goal" is answered by the commentator's words and
the scoreboard's OCR, which is the honest edge. `--scenario moments`
runs it; `--video <path>` loads a file instead of the library (no
Photos/TCC dialogs in a shell-driven Mac run — export follows the flag,
file in, file out). `ios/bench/moviefixture.swift` generates the test
clip: 40 s of synthetic match with a burned-in scoreboard, spoken
commentary (an explicit English voice) and a crowd-noise bed. The
recorded take (moment-seek-demo.mp4): "Find the moment they say goal" →
search_transcript hits 17.3–19.3 s "What a goal an absolute rocket…" →
"Keep only that moment." → keep_range(17.3, 19.3), 40 s → 2 s →
"Export it." — a 2-second goal clip in the export folder, fully
offline.

What the stage build taught (2026-08-21, all measured on the take):

- **The edit vocabulary can trip the safety rails.** "Cut the video down
  to just that moment" came back "may contain sensitive or unsafe
  content" from Apple FM — beat reworded to "Keep only that moment."
  The guardrail reads the verb, not the domain.
- **`shouldReportPartialResults = false` returns the LAST utterance
  window only.** Five commentary lines in, one out: the recognizer
  commits and resets across pauses, the intermediate commits ride
  partial results, and the single final carries the tail. The fix
  accumulates segments from every callback, deduplicated by timestamp
  (`VideoEditBox.transcribe`, shared with auto_captions — which had the
  same latent bug).
- **TCC attributes a naked binary to its parent shell.** Launching
  `LFMToolsMac` straight from Contents/MacOS crashed on the speech
  permission ("missing usage description" — the built Info.plist has
  it); the responsible process was the terminal. `open -n <app>
  --args …` fixes the attribution; the run scripts' bench mode never
  hit this because the fakes touch nothing permissioned.
- **The recognizer follows the device locale even when no such
  recognition locale exists** ("en_JP"): transcription came back
  garbled until the fixture spoke with an explicit English voice and
  the recognizer fell back to en-US
  (`SFSpeechRecognizer(locale:)` chain in transcribe).
- **A window-layer screencapture (`-l <windowid>`) records the app
  alone, even occluded** — the take is 92 window shots at ~0.5 s
  assembled to mp4, nothing else on the screen ever enters the frame.
  Tooling now lives in `ios/bench/takekit/`; taste, material rules and
  the post formula in docs/demo-playbook.md.

The real-footage take (2026-08-21, Pexels street→beach-puppy composite,
`--beats` flag): "Find the moment the dog appears" → the frames index
answers 14–23 s → keep_range → a 9-second dog clip exported. What it
taught, beyond the playbook:

- **The classifier speaks in scene nouns; the detector rung carries the
  objects.** VNClassify never said "dog" about a backlit puppy filling
  half the frame (outdoor/ocean/street only) — VNRecognizeAnimals
  (dog/cat) put the rows in. The cost ladder is real: classifier →
  specialized detector → (next) CLIP.
- **Verification can veto retrieval.** The self-check ritual, pointed
  at one exact frame with free-worded options, answered "none of
  those" and the model concluded "no dog" — against its own search
  hit, twice. Fixes that held: checks are range-aware (±0.6 s, runs
  merged at 3.2×step) and option-tolerant (negation partition, yes/no
  answered from the question's content words).
- **Answers follow the verdict word, not the evidence list.** "none of
  those — … shows: dog" was read as *no dog*; two later empty sweeps
  outvoted one earlier hit. Search hits now open with "found", and
  the check's verdict word carries its truth. After both, the run is
  clean; take variance remains (one pseudo-ask retake), which is what
  the playbook's retry rule is for.

What is new for the bench to score, in order of ambition:

1. **Clause→index routing** — seen/said/written queries each land on their
   index; `auto_captions` (the subtitle tool) must not be grabbed by
   "says"; `add_caption` must not be grabbed by "shown on screen".
2. **The timestamp copy out of a result** — the split-at-playhead
   competence with the number moved one step further away: not in the
   state, not in the words, but in a tool result the model just read.
   `seek`/`keep_range` args are scored with `number`+`tol` against the
   canned rows.
3. **The chain** — find → keep_range → export out of one sentence
   ("Cut out just the penalty and export it").
4. **Knowing what's missing** — "just that one moment" with no moment
   named is ask_user; a red-card query finds nothing and the honest
   answer is "there isn't one" (the echo returns an empty result on
   purpose — no bare "card"/"カード" key on the yellow-card row).
5. **The old room still works** — split-at-playhead and trim regression
   cases with the six new tools present.

The canned match (what a case can point at):

| index | moment | when |
|---|---|---|
| frames | kickoff | 3–10 s |
| frames | the keeper's diving save | 130–136 s |
| frames | a yellow card | 158–163 s |
| frames | **the first goal** — header, celebration | 214–226 s |
| frames | heavy rain starts | 320–330 s |
| frames | a substitution | 380–390 s |
| frames | **the penalty** — awarded, then converted | 440–462 s |
| frames | the final whistle | 592–600 s |
| transcript | "What an absolutely incredible save!" | 131.5 s |
| transcript | "He rises highest — and it's in!" | 213 s |
| transcript | "And that's half time." | 299 s |
| transcript | "The referee points to the spot — it's a penalty!" | 440.5 s |
| transcript | "He sends the keeper the wrong way — two nil!" | 457 s |
| screen text | scoreboard 0-0 / →1-0 / →2-0 | 0 / 218 / 458 s |
| screen text | "HALF TIME" — none; it is spoken only | — |
| screen text | banner "ATTENDANCE 48,113" | 520–526 s |
| screen text | "FULL TIME BLU 2-0 RED" | 597–600 s |

A "goal" query returns **two** rows (the header and the converted
penalty) on purpose: "the first goal" is shortlist reasoning — candidates
come back, the model picks by the words, and the seek/cut args say which
one it picked.

Design notes

- **A result is a state line that arrives late.** The video pack's rule
  ("take times from the state, never guess one") extends across the tool
  boundary: the instructions name search results as the second legitimate
  source of times (`ToolBox.momentsInstructions`). Everything else is the
  video pack's contract unchanged.
- **`keep_range`, not split-split-delete.** Cutting a moment out via the
  primitives is a four-call walk (split, split, delete, delete) with
  renumbering between calls — a chain the compound lesson (make_reel)
  already ruled against for small models. One call, two numbers, both
  scorable.
- **check_moment is the long tail, not the judge.** The orchestrator
  thesis's boundary: the indexes answer "where", the check answers one
  forced-choice question about one frame the search already shortlisted.
  It is never the stop condition of anything.
- LiteRT note: `check_moment`'s `options: [String]` is the first array
  argument in any pack — fine for Apple FM's guided decoding, to be
  verified against the LiteRT bare tool-list style when the pack goes on
  device.

日本語版は同じ 40 ケースの後半 20(cases.json)。JA の query 引数は採点
しない(JA/EN どちらの語で検索しても正しい — money パックの前例)が、
canned 行のキーワードに かな を持たせてあるので、JA クエリでも空振り
しない。

What the Mac runs taught (r33–r36, all 2026-08-20, Apple FM via
run-mac.sh — smoke tests, not table rows; fresh session per case, and
the same case flips across rounds, so read the taxonomy, not one run):

- **9/40 → 16 → 17 → 12.** r33 ran with no stop contract in the
  instructions; r34 added the retrieval-shaped stop (one index; no
  self-check; "answer and stop" / "edit and nothing more") plus the
  keep_range and check_moment clauses; r35 fixed r34's own goal (below);
  r36 was the A/B that removed the fallback license and lost — the
  committed config is r35's, 17/40. Between rounds two cases were
  re-ruled (the misses became the three-index sweep r33 measured as the
  model's honest behavior in both languages) and one answer keyword list
  learned "isn't".
- **The claims the pack was built on hold.** The first call is the right
  index almost every time the clause names its modality — "says" finds
  the transcript, "shown on screen" the screen text, in both languages.
  The timestamp copy works: every edit that followed a search took the
  result's numbers, not inventions — `keep_range(440, 462)` from "cut
  out just the penalty", `(214, 226)` from 「最初のゴールの瞬間だけ残し
  て」 (r35), `seek(214)` after the goal search. The verify chain
  (search → check_moment with the copied time) passed in both languages,
  and the split-at-playhead / trim regressions passed every round — the
  old room survived six new tools.
- **The retrieval ritual does not stop — the loop lane's finding,
  search-shaped.** A search that succeeded is followed by check_moment
  verifying its own result ("which goal comes first", asked of a VLM
  about a list arithmetic already ordered), or by the other two indexes
  "to be sure"; one JA case (r36) alternated frames/transcript for 29
  calls — the twin of the polish loop's 28 rounds without a stop. The
  stop contract moved the score 9 → 17 and no further; the sweep
  survived its A/B (r36 removed the "only when it finds nothing" license
  and the run got *worse*, 12/40, with the sweeps intact) — like the
  look-first prefix, it is character, and wording will not remove it.
- **The ask hole: an anaphor with no antecedent is resolved, not
  asked.** "Cut out just that one moment" — which moment was never said
  — produced `keep_range(0, 240)` from the playhead in three rounds of
  four (EN), and an index sweep for 「あの場面」 (JA). The
  argument-level ask that fixed add_caption did not hold here — the
  first measured failure of that pattern. Open: the state may need to
  say what "that moment" cannot mean (no moment is selected), the
  state-answers recipe pointed the other way.
- **Clause routing reads the verb, not the world.** "When does the rain
  start?" carries no perception verb, and rain-is-visual is world
  knowledge the router doesn't apply: it went to the transcript first in
  three of four rounds. Explicit modality routes; implicit modality
  sweeps or misroutes. A product either words its indexes into the
  question (the check_moment options lesson) or sweeps by design.
- **A tool description's stop clause ends the turn, not the cleanup.**
  r34's keep_range said "no split_clip first, nothing after" — and the
  model obeyed "nothing after" into dropping the export the request
  asked for, twice, with perfect keep_range args. The clause meant "no
  cleanup calls"; it was read as "the turn ends here". Scope stop
  clauses to the named tool, never to the turn.
- **The honest empty answer works.** The red-card miss swept all three
  indexes and said "isn't present" / 「見つかりませんでした」 in every
  round — fetch-then-admit, not invention: the retrieval archetype's
  ask_user lesson, answered by tools.

r37 (2026-08-21) is the first round scored against a canned world level
with the app's. Everything above was measured against a stricter check —
one that refused by name whatever it could not match, and left the model
to read the refusal as absence — and against a search whose hits opened
with a bare count. The canned check now runs the real matcher's
semantics (negation partition, yes/no decided by the question's content
words, the verdict word first with the evidence tail behind it) and the
canned search opens with "found", so r33–r36 and r37 are not the same
question asked twice. The denominator is 43: three cases from the
real-footage take's failure modes joined the EN block.

- **14/43 — 13 of the old 40, against r35's 17 on the same config.**
  Six of the forty moved down, two up; one run each side, fresh session
  per case, so the number reads as a band, not a regression. What is not
  noise-shaped: check_moment went from 7 calls in 7 cases (r35) to 15 in
  14 (r37), and five of the six new failures grew a check_moment where
  r35 made none — four of them checking a search that had already
  succeeded (「実況が…」 twice, "find where the scoreboard changes to
  1-0", "find where the commentator says 'incredible save'", all
  single-call passes in r35), and one opening with a check on
  「この動画、何秒ある?」, a question the state already answers. A check
  that now answers something usable gives the retrieval ritual somewhere
  to go; the stop contract is unchanged and still does not stop it. (The
  sixth is the ask hole again — "cut out just that one moment" resolved
  to keep_range. The two that moved up: m-en-written-3 lost the check it
  had in r35, and m-en-cut-1 finally made the search → keep_range chain
  it declined to make at all.)
- **The verdict semantics carry, and the ritual is what fails the new
  cases.** All three new cases passed `answerContains`; two failed on
  selection. m-en-check-2 (yes/no at 460 s) got "yes" out of the check
  and said "Yes, a penalty is being taken" — after searching the
  transcript for "penalty" first, for a frame it had been handed the
  time of. m-en-check-3 (negated options at 100 s) worded its own
  options "goal present" / "no goal", the negative carried the verdict,
  the answer said "there is no goal" — and then the model swept all
  three indexes and cut the timeline to 0–6 s, an edit nobody asked
  for. The backport does its job: the verdict word is now the answer in
  the bench too. What it exposes is the ritual, again.
- **The veto trap did not fire on its first run.** m-en-veto-1 passed:
  the model worded its check options as timestamps ("starts at 320 s" /
  "starts at 330 s") rather than a yes/no, so the check agreed with the
  search and the final answer kept 320 s. The measured veto needs a
  yes/no question whose words the truths cannot answer — the shape the
  real-footage take produced — and the model did not choose that shape
  here. The case is worth keeping precisely because the trap is the
  model's wording choice, not the tool's: it will fire on the rounds
  where the model asks "is it raining".
