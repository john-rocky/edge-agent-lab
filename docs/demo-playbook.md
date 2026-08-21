# The demo playbook — taste, materials, takes, posts

The bench proves; the demo shows. A lane is not finished when its JSONL
lands — it is finished when a person who follows nobody's benchmarks sees
a video and understands what just became possible on a phone. This file
is the taste layer: what to build a take around, how to pick footage,
what a post says, and the specs for the next builds — written so an
implementation session can execute without re-deriving the judgment
calls. Decisions here were set 2026-08-21 (user), during the moment-seek
demo build.

## What the demo is selling (the impact axis)

**The on-device future.** Every take exists to make one sentence
believable: *your phone can already do this, alone.* The three proofs a
take should carry, visibly:

1. **No cloud.** The HUD says on-device; the post says fully offline.
   Airplane-mode is the strongest single word available.
2. **No extra models** where true — the moment-seek index is Vision +
   Speech + Apple FM, i.e. the OS's own shelf (the orchestrator thesis
   on camera). When a model repo piece joins (CLIP), say which piece
   and why, plainly.
3. **The words are the interface.** The killer context is the **small
   screen + voice**: an iPhone held in one hand, a sentence spoken, an
   edit done. Mac takes are stand-ins while the phone is away — keep
   the window phone-shaped (the 515×720 Catalyst window reads as a
   phone), and when the device returns, re-record the flagship takes
   with `--voice` on the handset. Voice is the demo of the input layer;
   never let a take imply typing is the product.

## Take design rules (what いけてる means here)

- **One visible before/after per take.** The money shot is state
  change the eye can verify: the timeline collapsing 24 s → 9 s, the
  frame going portrait, the export toast. Design the take backwards
  from that shot; if the change isn't visible on screen, the take has
  no climax and no post.
- **Three beats, voice-sized.** find → act → export. Short beats read
  as speech; long beats read as programming. If a beat needs a comma,
  split it or cut it.
- **The take must read muted.** X autoplays silent: chat bubbles +
  timeline + frame are the whole narrative. Never rely on audio for
  the story (audio in the *footage* is fine — it is what the transcript
  index eats).
- **Real footage for posts; synthetic for pipelines.** moviefixture.swift
  exists to prove plumbing (OCR/ASR rows land where planned), not to be
  filmed. A synthetic take is publishable only as an explicitly-labeled
  pipeline demo, and a real-footage version beats it every time.
- **A take is a take.** Retries until the model behaves are honest —
  flakiness accounting lives in the bench, not in the recording. What
  is never allowed: faking a tool result, trimming the video to hide a
  wrong call, or a beat that only works because the canned world was
  bent for it.
- **Never record the user's display.** Window-layer capture only
  (`screencapture -l <windowid>` at ~0.5 s cadence → assemble to mp4).
  It records the app even occluded and can never film someone's other
  windows. Tools: `ios/bench/takekit/` (windowrect / capture loop /
  assemble; concat for footage prep).

## Material selection (素材選定)

- **Source: Pexels** (free license, no attribution). Download via
  `curl -L https://www.pexels.com/download/video/<id>/`.
- **Pick footage the shelf can actually see.** VNClassify speaks in
  scene nouns — outdoor, ocean, street, vehicle — and will *not* name
  events ("goal") or many objects (it missed a backlit puppy filling
  half the frame). The dedicated detectors carry the objects:
  VNRecognizeAnimals = **dog and cat only**; OCR carries anything
  written (signs, scoreboards, slides); Speech carries anything said.
  So castable subjects today: dogs, cats, written text, spoken lines,
  and strong scene contrasts. Everything else waits for the CLIP rung.
- **Scout before you word the beats.** The index logs its vocabulary
  (`MOMENTS visual labels:` / `MOMENTS transcript rows:`). Run once,
  read the log, then write beats in the words the index actually
  holds. A beat worded against labels that never fired is a scripted
  failure.
- **Two clips, subject in exactly one.** street→beach-dog gives "find
  the dog" one honest answer. Same-subject-in-both is the shortlist
  demo — harder, save it for after the check tool is proven on takes.
- **Locale audit before recording** (x-post-style rule): EN post means
  EN everything in frame — synthesized voices explicitly English
  (`say -v Daniel`; the system default followed the device locale and
  wrecked recognition), on-screen text EN, names neutral, no currency
  marks. One yen sign killed a finished post once.

## The post formula

1. First sentence = the reader's breakthrough, spoken plainly, no
   numbers: what they can now say to their phone and what happens.
2. Then the proof terms: fully offline / on-device model / which OS
   parts did the judging. Numbers where they fit (2 seconds, 24 tools).
3. Experiment framing kills product-smell: "a sample of how far
   on-device agents go."
4. ≤280 chars (URL = 23). JA translation attached for checking, never
   posted as the main.
5. The video is the post; the text captions it. If the text explains
   what the video failed to show, fix the video.

Current draft (moment-seek, revise when the real-footage take lands —
lead stays, middle names the animal detector if the dog take is used):

> Tell your video editor "find the moment they say goal" — it searches
> the on-device transcript, cuts the timeline to those 2 seconds, and
> exports. Fully offline: Apple's on-device model routes the calls;
> Vision + Speech built the index. A sample of how far on-device
> agents go.

## Implementation specs (execute in order; no new judgment needed)

### A. Finish the real-footage take (in flight)

Remaining defect: check_moment's option matching. The model words its
options freely ("appears" / "does not appear", "no dog") and a miss
returns "none of those", which the model reads as *absent* even when
the truths list names the thing. Spec:

1. Partition options by negation markers (`no `, `not `, `n't`,
   `none`, `without`, leading `no`) into positive / negative.
2. Direct match first, positive options only: option text ↔ truth text,
   contains either direction (covers "0-0" vs "1-0" scoreboard checks).
3. Yes/no-shaped options (⊆ {yes,no,true,false}): presence = any
   content word of the *question* (≥3 chars, stopword-filtered) matches
   truths; answer "yes —"/"no —" + the truths list.
4. Otherwise: presence = any content word of question + positive
   options matches truths → first positive option, else first negative
   option, else "none of those — …". Always append "— around N s the
   frame shows: …" so a wrong verdict is self-correcting downstream.
5. Rebuild, scout once (`--beats "Find the moment the dog appears.|Keep
   only that moment.|Export it."` on real-take.mp4); a clean run shows
   search → (check confirming) → answer naming 14–23 s, then
   keep_range(14, 23), then export of ~9 s.
6. Record with takekit, assemble at 2 fps, deliver mp4 + the exported
   dog clip.

### B. iPhone voice take (when the device is back)

`--scenario moments --voice`, the same real footage in the camera roll
(or `--video` file). Speak the three beats. Record via QuickTime device
mirroring. This becomes the flagship post video; the Mac take then
demotes to the thread's second tweet (the "how" shot).

### C. Bench backport (bench/stage parity)

- MomentEcho.check learns the same semantics as the real check
  (negation partition, yes/no + question words) — the bench must not be
  kinder than the app (r33–36 measured against the older, stricter
  canned check; note it in script.md when re-run).
- New cases from the take's failure modes: (1) verification-veto — a
  case where search hits and a follow-up check answers oddly; pass
  requires the final answer to trust the search hit (answerContains
  the timestamp). (2) yes/no check case. (3) negated-option check case.
- Re-run r37 with the same config; record deltas in script.md.

### D. JA takes and cases

JA beats on the same footage (「犬が出てくる瞬間を探して」). Open
question to measure, not assume: does the model translate the query to
EN for search_frames (labels are EN)? If not, either the JA case fails
honestly, or search learns a tiny JA→EN alias table for detector nouns
(dog/cat/犬/猫) — prefer the alias table; it is the same findability
rule the canned worlds follow.

### E. The CLIP rung (model repo lane)

Embedding index behind search_frames for everything the label shelf
cannot name: index time = frame embeddings at the same ≤90 samples;
query time = text embedding of the model-expanded phrase; hit = cosine
over threshold, rendered as the same Row shape. Then the measurable
A/B the ROADMAP promises: labels-only vs labels+CLIP hit rate on the
same footage set, same beats. This is where "find the goal" starts
working on footage with no scoreboard.

### F. Session hygiene for implementation sessions

Model: Opus is the default executor for A–E; return to Fable only for
new failure-mode taxonomy or when a spec here proves wrong in a way
that needs re-design. Keep every run's log lines (`MOMENTS …`) — they
are the scouting instrument. Commit messages carry findings, not
file lists (see git log for the register).

## 経験則 (take-lane heuristics, 2026-08-21 — candidates for recipes.md
once they recur)

- **The guardrail reads the verb, not the domain.** "Cut the video
  down" tripped Apple FM's safety filter mid-take; "Keep only that
  moment" sailed. Beat vocabulary routes around rails.
- **Verification can veto retrieval.** An unnecessary self-check that
  misfires outweighs a correct search hit in the model's final answer —
  the ritual turns a found thing into "not found". Checks must be
  range-aware (detectors flicker; ±0.6 s, merge gap 3.2×step) and
  option-tolerant, or absent.
- **Answers follow the verdict word, not the evidence list.** The model
  read "none of those — … shows: dog" as *no dog*. Any tool that
  returns a verdict must make the verdict word carry the truth; the
  explanation tail is for humans and logs.
- **shouldReportPartialResults=false returns the last utterance window
  only** — accumulate partial segments keyed by timestamp.
- **TCC blames the parent shell** for a naked binary; `open -n <app>
  --args …` restores attribution (the crash claims a missing usage
  description that is in fact present).
- **The recognizer follows a device locale that need not exist**
  (en_JP): explicit recognizer fallback chain, explicit fixture voices.
- **Scout, then word.** Never write a beat before reading what the
  index actually produced for that exact footage.
- **Detector rows start late — snap them to the scene boundary.** The
  animal detector first fired ~2 s after the cut that opens the dog
  scene, and the seek visibly missed the scene's head. "The moment" a
  person means is the scene containing the detection: walk the row
  start backward while the classifier's scene signature still matches
  (Jaccard ≥ 0.5), capped at 4 s. The find→**jump**→cut→export arc is
  the canonical four beats now — the jump is the "found it" shot, and
  it must land on the cut, not on the detector's first confident frame.
