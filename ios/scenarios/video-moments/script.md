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

r37b re-ran r37's config on r37's binary, before a line of spec D
landed: one round cannot tell a ritual from a coin flip, and every
reading in this lane is a difference between rounds. r38 is the first
round with the check's boundary fix, the JA verdict parity (negation
markers, detector-noun aliases) and the three JA mirrors in it — 46
cases, the JA block now carrying the same veto / yes-no / negated-option
trio as the EN.

- **The band: the aggregate belongs to the config, the case list is
  noise.** r37b scored 15/43 to r37's 14/43 — and on the old 40 the two
  rounds are identical, 13/40 each, against r35's 17. So is the check
  ritual: 14 cases, 15 calls in both rounds, where r35 made 7 in 7. Yet
  only 11 of those 14 case *identities* overlap, and 7 of the 40 cases
  flipped verdict between two runs of the same config. Read a single
  case's PASS/FAIL as a coin; read the round's totals as the
  configuration speaking. The r35 → r37 drop is therefore not a run
  artifact: a check that answers something usable gives the retrieval
  ritual somewhere to go, and it goes there every time.
- **17/46 in r38, 15/40 on the old 40** — two back inside the band, the
  ritual unmoved at 15 cases / 15 calls. Nothing in this round was aimed
  at the ritual, and nothing touched it.
- **The three JA mirrors fail three different ways, and all three are
  the point.** m-ja-veto-1: search 「雨が降り始める場面」 hits 320–330 s,
  then the check at 320 s comes back "none of those", the model sweeps
  the other two indexes and hedges — the veto its English twin dodged
  the same round. The cause is not the verdict semantics but the
  tokenizer: JA writes no spaces, so the question's content words are
  one long clause that no English label can contain, and presence can
  never be found. m-ja-check-2: the model asked its question in English
  with JA options 「はい」/「いいえ」 — and 「いいえ」 is not a negation
  marker (the markers cover the 〜ない / なし forms), so the pair reads
  all-positive, presence fails, and "none of those" becomes "The PK
  scene is not present". A JA yes/no pair needs its own partition; that
  is the next ruling, not a wart to leave. m-ja-check-3: the JA negation
  partition did work — 「ゴールあり」/「ゴールなし」 split, and the
  positive matched the truth 「ゴール」 by name — but the model searched
  first and then checked 214 s, the goal it found, instead of the 100 s
  the case asked about. Two of the three also moved the asked time
  (450 s for 460, 214 s for 100): on JA input this model treats a
  timestamp in the request as a suggestion.
- **The boundary fix holds, and it says so in one line.** Both scouts on
  journey.mp4 logged `MOMENTS check at 12 s sits on a cut — keeping the
  forward scene: 12.6 s, 13.2 s, 13.8 s` — the centre frame dropped with
  the backward one, two replacements walked in from ahead. The check's
  evidence tail is now `cat, dog, liquid, water, water body, ocean`
  where the same check on the same second returned `plant, outdoor,
  foliage, land, dirt road, road, path, trail` before: the beach scene
  the question was about, not the forest that ends at the cut. Beat 1
  trusts the hit in both languages — "The dog appears around 12 seconds
  in the frame" (EN), "I found a moment around 12 seconds where a cat,
  dog, … are visible" (JA) — where the pre-fix JA run on the same beat
  answered "I couldn't find the exact moment of the dog appearing". EN
  then ran the whole arc clean: seek 12 s → keep_range 12–19 → export,
  25.3 s → 7 s. JA reached the export too, but beat 2 added a
  split_clip after its seek, and
  beat 3's keep_range took 12–25.3 s from the split instead of the row's
  12–19 — the arc lands, the arithmetic does not. That is the JA retake
  note for the flagship take.
- **The model does not translate the query. It hands the index the
  user's Japanese.** Measured, not assumed: a probe beat
  「雪が映っている瞬間を探して。」 on footage with no snow came back
  `no moments found for "雪" in the picture` — the bare JA noun, straight
  through. The bench agrees at scale: 29 of the 37 search calls the JA
  cases made in r38 carried JA query strings, and every one of the eight
  English ones copied a Latin or numeric token out of the request itself
  ("PK", "FULL TIME", "0-0", "300 s"). Not one JA noun was rendered into
  English. The detector-noun alias table is therefore load-bearing, not
  a nicety — it is the only reason 「犬が出てくる瞬間」 finds a row whose
  text is "dog" — and the same rule now carries the check's presence
  test. Its limit is its length: 犬 and 猫 are aliased, 雨 and ゴール are
  not, which is exactly where m-ja-veto-1 breaks. (Aside, unscored: the
  Mac model answers 20 of 23 JA cases in English. The cases accept both
  languages' keywords, so it costs nothing here — but a voice take on
  the phone is a spoken answer, and that is a take-lane question.)

r39 is spec D2's round, both fixes in both checks: 「いいえ」 joins the
negation markers (with 「ません」, the polite negation ありません/いません
are two instances of, and the kanji 無い/無し), and a check whose
presence test has nothing it could ever test with now says it cannot
tell instead of voting no.

- **16/46, 13 of the old 40 — the band, one run.** r38 was 17/46 and
  15/40; r37 and r37b were 13/40 twice before it. Nothing here is a
  regression and nothing here is a win: the aggregate belongs to the
  config, and this is one round of it. What moved outside the band is
  the ritual. check_moment went from 15 cases / 15 calls to 19 / 20,
  its highest yet against r35's 7 in 7 — and nothing in this diff
  touches the tool description or the stop contract, since the check
  only ever speaks after it has been called. The ritual grows on its
  own.
- **The はい/いいえ partition fires; the cannot-evaluate branch never got
  the chance.** Replaying every check call of both rounds through the
  old matcher and the new one, exactly one verdict changes, and it is
  the same case in each: m-ja-check-2's 「はい」/「いいえ」 pair stops
  reading all-positive and answers 「いいえ」 where it answered "none of
  those". The blindness branch fired zero times in twenty calls — for
  a reason worth having measured, which is that the model does not hand
  the check a Japanese question. It words the check in English even on
  JA cases (16 of 20 calls in r39, 10 of 15 in r38), and on the four
  occasions it did ask in Japanese it wrote its options as timestamps,
  「320–330 s」 — digits being exactly the ASCII the truths could hold,
  so the presence test counts as runnable and reports a real absence.
  The ruling is right about the failure; the failure needs a check the
  model asks in Japanese *and* answers with Japanese options. That is
  the real-footage shape, not the canned world's — a JA question meeting
  an English label shelf, which is where the alias table is the only
  bridge.
- **m-ja-check-2 still fails, one layer down, and the failure is now
  honest.** With the partition in, the check evaluates the single
  content word the model's English question left it — "scene", against
  truths reading "penalty, spot, ペナルティ, PK, goal" — finds it absent,
  and answers 「いいえ」. The model says "The PK scene is not at 460
  seconds" about a frame the penalty row covers. The verdict is
  evaluated rather than blind now, and still wrong: the question the
  model wrote threw the noun away and kept the wrapper. Two of the
  three JA check mirrors also moved the asked time again (442 s for
  460, 214 s for 100) — on JA input a timestamp in the request stays a
  suggestion.
- **The JA beat 2 split_clip did not recur — two scouts, neither
  showed it.** Two JA runs on journey.mp4 and one EN, all three the
  same arc: `MOMENTS check at 12 s sits on a cut — keeping the forward
  scene: 12.6 s, 13.2 s, 13.8 s`, the evidence tail `cat, dog, liquid,
  water, water body, ocean`, beat 1 trusting the search hit in both
  languages, a bare seek to 12 s, keep_range 12–19 s, 25.3 s → 7 s.
  r38's split_clip was a round, not a rule, and there is nothing to
  reword. What the scouts caught instead is a beat 4 hole the video
  pack already knew: 「動画を書き出して。」 went to auto_captions in the
  first JA run — "could not transcribe: Operation Stopped", after which
  the model declined to export at all — and to export_video cleanly in
  the second. The bare 書き出す is ambiguous to the router in a way
  "Export it." is not; EN exported 7 s at 1280×720 on the first try.

r39b and r40 close the D2 lane. r39b re-ran r39's exact config on r39's own
binary, before a line of the tokenizer fix landed; r40 carries it; and
between the two rounds beat 4 was scouted twelve times on journey.mp4 —
four wordings, three runs each, every other beat held fixed. The wording
question is the flagship take's last open one, so it went first: bench runs
and stage runs share the app bundle and the support folder, and neither can
be read while the other is in flight.

- **The ritual's jump was the configuration, not a coin.** r39's 19 cases /
  20 calls looked like the one number outside the band. r39b, same binary
  and same cases, made 18 / 20; r40 made 18 / 20 again. Three rounds now
  sit where r38 sat at 15 / 15 and r35 at 7 / 7, so the plateau moved and
  stayed moved — and nothing in any of these diffs touches the tool
  description or the stop contract. The aggregates say it and the case
  lists never could: 16/46 in all three rounds, while the old-40 subset
  read 13, then 15, then 14, and the JA/EN split went 4/12 → 6/10 → 7/9
  with the first two rounds sharing a binary. Read the round; the cases are
  a coin.
- **Beat 4's wobble is real and it belongs to the control alone — one miss
  in twelve.** 「動画を書き出して。」 exported twice and on its third run
  called `auto_captions`, got "could not transcribe: Operation Stopped",
  and answered 「動画の音声が認識できませんでした。何か音声が聞こえるで
  しょうか？」 without ever reaching export — the r39 scout's failure,
  reproduced on demand a day later. 「エクスポートして。」, 「動画ファイル
  として書き出して。」 and 「この動画を保存して。」 each went to
  `export_video` three times for three, 7 s at 1280×720 out of 25.3 s every
  time, and all twelve runs put beat 3's keep_range on 12–19 s. Three runs
  is a thin sample and the three alternatives tie clean, so the finding is
  not a ranking among them: it is that the ambiguity lives in the bare verb.
  Give 書き出す a noun to land on (ファイルとして) or drop it for a word with
  no transcription neighbour (エクスポート, 保存) and the router stops
  guessing.
- **The two tokenizers agree now, and it buys exactly one verdict.** The
  check's `contentWords` dropped every token under three characters while
  search kept a two-character token carrying a digit; the check now keeps a
  token that is long enough, carries a digit, or is written as an acronym.
  Replayed over all 75 recorded check calls of r38, r39, r39b and r40, the
  new rule changes exactly one verdict, and it is the same one every round:
  m-ja-check-2's 「いいえ」 becomes 「はい」 once "PK" survives the floor to
  meet the penalty row's own key. r40 shows it live — the case answers
  「はい」 and its answer keyword passes for the first time in four rounds —
  and the case still fails, because the model checked 442.75 s of a case
  that asks for 460 ± 0.1. Twenty-four of the 75 calls gained a token and
  only that one changed an answer: the rest are digits split out of "1-0"
  or "440.5" in calls that had already matched an option by name. The floor
  was a real hole and a small one, which is what a parity fix should be.

r41 is the control for the take lane's first product-side change, and the
change is one flag: the stage learned `--without <names>`, which cuts the
named tools out of whatever pack `--scenario` chose — the bench's `--only`
turned around, for the other lane, because a take's room is a product
decision where the bench's toolset is a measurement. The flagship now
launches with `--without check_moment` and says so in its own log
(`TOOLS 23 — without check_moment`); a name the pack does not hold is an
error the way `--only`'s is, one ERROR line and no beats (verified with a
bogus name). Nine stage runs on journey.mp4 measured the emptier room, six
JA and three EN, each launched with `open -n` and the app quit between
them: **all nine ran the whole arc — search_frames → seek 12 s →
keep_range 12–19 → export, 25.3 s to a 7.000 s file every time, ffprobed
rather than believed from the toast** — and every failure mode the check
brought with it is gone. No beat-1 denial in nine runs, where three of the
twelve check-in-the-room scouts denied their own search hit
(「見つかりません」/「見ない」/"cannot be found"); no index sweep, where two
of twelve swept; no spurious `set_clip_speed`, where two of twelve fired
one; no beat-4 miss, where one of twelve went to `auto_captions`. What the
room did not lose is the second call: **beat 1 grew a `seek` in 9 of 9
runs**, the model jumping to the moment before it is asked to, which
spends beat 2's money shot a beat early — and en-2's stray seek ran on to
19 s, so its beat 2 landed on the scene's tail instead of the cut. The
ritual moved rather than left; take away the tool that answers and the
slot fills with the next tool that can, which is the plateau heuristic
read from the other side. The other wart is language: 1 of the 6 JA runs
answered in Japanese where 8 of 12 did with the check in the room, and on
a voice take the bubble is the whole muted narrative. Counting a take a
person could ship without a retake — right tool per beat, right numbers,
beat 1 naming 12–19 and trusting the hit, bubbles in the beat's language —
**1 of 6 JA and 2 of 3 EN**, and none of the nine if the beat-1 seek is
counted disqualifying. Six runs and three runs are thin samples; the
aggregate belongs to the configuration and none of this is a case list.
r41 itself re-ran the bench unchanged on the same binary — the bench never
passes `--without` — and the row is 18/46, 17 of the old 40, JA 7 / EN 11,
check_moment 19 cases / 21 calls, with all 24 tools in the run record: the
flag changes nothing the bench measures. That is the top of the band
rather than a move (r38 17/46 and 15/40; r39, r39b and r40 all 16/46), and
the ritual sits where it has sat since r39.

r42 is the language ruling's round, and the ruling fails. The stage now
adds one line of its own on top of whatever pack it assembles — "Answer in
the language the request was made in." — at `StageModel`'s single session
site, above `stateInstructions` rather than inside it, so
`ToolBox.momentsInstructions` stays byte-identical to what r38–r41
measured and the bench keeps its control. Nine more stage runs on
journey.mp4, the same three beats and the same 23-tool room: **1 of the 6
JA runs answered in Japanese**, which is exactly the 1 of 6 the line was
written to fix, against the 8 of 12 the rounds with the check in the room
managed with no language instruction at all. The sentence did reach the
model — the running process loaded the dylib that carries it and the
append is unconditional — so what is refuted is the instruction, not the
wiring: on this model, on this pack, the answer's language is not
something the instruction block decides. (Asked point blank in a throwaway
run, the model denied having any language instruction, which is worth what
any model's account of its own prompt is worth: nothing alone, suggestive
beside the behaviour.) The rest of the round is the cleanest the take has
measured — **all nine ran search_frames → seek 12 s → keep_range 12–19 →
export, 25.3 s to a 7.000 s file every time, ffprobed, with no spurious
call in any of the nine** — and **every beat-1 seek landed on the cut at
12 s**, where r41's en-2 ran on to 19 s: that stray was a coin, and the
found-it shot stays on the sentence that asks for it. Beat 1 named the
range in 8 of 9 (en-2 said "at 12 seconds") and no JA beat 1 doubted its
own hit. Shippable without a retake — right tool per beat, right numbers,
beat 1 naming 12–19 and trusting the hit, bubbles in the beat's language —
**1 of 6 JA and 2 of 3 EN**, the JA number being the language line's
alone. Six runs and three runs are thin. The bench re-ran unchanged on the
same binary: **16/46, 13 of the old 40, JA 7 / EN 9, check_moment 18 cases
/ 24 calls**, the same 24-tool list in the run record — the band's floor
rather than a move, and the ritual where it has sat since r39. The JSONL
carries no instruction text, so the no-leak claim is verified from the
source instead: the pack literal hashes identical to r41's, `Sources/Bench`
untouched, `answerLanguageLine` named at exactly two lines and both inside
the stage's session assembly — and the bench's own JA cases answered in
Japanese 7 of 23 times, inside the 4–7 the unchanged instructions have
produced every round.
