# Polish — hand it a photo and say nothing

The demo. The photo goes in with no words at all; the model looks and
makes it look its best — judging what *this* picture needs and applying
the edits one after another, gently. Then three words each. Apple's model,
natively (`Attachment` in, `ImageReference` out); `--voice` for the
spoken beats. Launch:
`--autorun --backend apple --scenario polish [--voice]`.

| beat | say | expect |
|---|---|---|
| 1 | *(nothing — the photo alone)* | a chain of gentle edits chosen from the pixels: exposure / brightness / warmth / contrast / color / straightening, then one sentence on what changed and why |
| 2 | A little more. | the same direction, one more step |
| 3 | Now cut her out from the background. | remove_background |
| 4 | Save it. | save_edited_photo |

日本語版: (無言) → 「もう少し。」→ 「彼女を背景から切り抜いて。」→ 「保存して。」

Design

- **The silent contract lives in the instructions**: "a photo sent with
  no words means: make it look its best — judge what this picture needs
  … apply those edits one after another, gently, then say in one sentence
  what you changed and why." The chat honours the same contract: attach a
  photo, send with the field empty.
- **Steps, not numbers.** The vision tools take `direction` (brighter /
  darker, warmer / cooler, more / less…) and `strength` (a_little / some
  / a_lot → 15 / 35 / 60 %, or 0.3 / 0.7 / 1.2 stops). Asked for 0–100
  the model answered 100 every time — the recipe "vague amounts land on
  the rail", applied. "A little more" is a_little in the same direction.
- **The model is shown its own work**: every beat attaches the photo as it
  is now, so "a little more" is judged on the already-edited picture.

Not yet run — the phone was in use. Recording notes: pick a photo that
*needs* something (a touch dark, a little cool) so the silent beat has
work to do; a person in it makes beat 3 land; beat 4 saves a copy —
delete it before the next take.

## The loop (2026-08-20, Mac lane)

The first cut of the goal-driven archetype (ROADMAP "Beyond the input
layer"): perceive → judge → act → perceive the result → judge again.
The bench drives it — round one is the silent beat with a defect
fixture attached; after every round the runner re-attaches the photo
*as the model's edits left it* behind one reprompt, and a round with no
tool call is the stop. Cases carry the fixture's ground truth
(`needs`/`avoid`: ops by tool + direction, of which a correct run makes
at least one and never one, respectively), `maxRounds` caps a run that
will not stop, and the JSONL row records ops per round, stop,
oscillation and per-round ms. The room is the vision pack with real
edit bodies — the bench's one deliberate break with the all-canned
rule, because a canned "done" would loop the model over an unchanged
picture. Fixtures are generated (`bench/fixtures.swift`) from one base
photo with the app's own filter recipes run backwards — dark/bright
(±1.4 EV), cool/warm (the warmth recipe at −110/+70), flat (contrast
0.68), dull (saturation 0.35), good (untouched) — so every defect is by
construction fixable by the tool that names it. The base photo is not
committed (a macOS wallpaper, locally); regenerate and eyeball before a
run — at −70 the cool cast was invisible to eyes too.

Findings, Apple FM on the Mac (r27/r28: the open reprompt, twice; r32:
forced-choice reprompt; r29: the loop cases under the one-turn polish
contract):

- **One edit per round holds; the stop never comes.** Every round of
  every case made exactly one call — and 0/7 stopped at four rounds,
  0/2 at six (r27/r28). The prose declares "It is done" *in the same
  round as the call*, twice it handed the stop back ("Is it
  finished?"). "Call nothing when it looks its best" is an exit the
  model never takes in the act direction.
- **The edits are a ritual, not a judgment.** Nearly the same sequence
  on every fixture — brighter, more contrast, warmer, then
  auto_enhance — whatever the defect: exposure *up* on the overexposed
  fixture, warmth *warmer* on the orange one, and the desaturated
  fixture never saw the saturation tool in four rounds. The
  judgment→op mapping exists only where the defect happens to lie
  inside the ritual (dark, flat). No oscillation ever: the loop does
  not hunt, it monotonically applies the prior. Why: see
  ../polish-see/script.md — the perception is there and never
  consulted.
- **Forcing the judgment cracks the door** (r32: the reprompt now asks
  "does it still need improving — yes or no?"): the first genuine stop
  appeared — loop-dark-r6, five edits then a no-call round and "The
  photo now looks great. It is done." — 1/9 overall, same ritual
  otherwise. The stop exists; the room's pull still wins eight times
  of nine.
- **The ceiling is context, not latency.** loop-bright died in round
  two of r32: the model answered round one by *fabricating a base64
  image in markdown* — the photo is on stage, it invented a fake one
  inline — and the transcript blew the 8192-token window. Iterations ×
  image attachments is the real on-device budget for any
  perceive-again loop, and one runaway answer spends it at once.
- Under the one-turn polish contract instead (r29), the good fixture
  correctly gets zero calls — the only passes — but bright and cool
  also stop untouched: the no-call answer exists in that contract, it
  just is not pixel-accurate. And round one is almost always
  auto_enhance: "make it look its best" with no op named is that well.

Raw JSONL: ../../bench/results/2026-08-20-mac-r27/ … -r32/.
