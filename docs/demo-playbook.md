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

The real-footage variant (dog take; update the numbers to the shot
take before posting — the journey cut is 12–19 s, 7 s out):

> Say to your video editor: "find the moment the dog appears" — the
> on-device index answers 12–19 s, the AI jumps there, cuts the
> timeline to those 7 seconds and exports. Fully offline: Apple's
> on-device model + the OS's own vision. A sample of how far
> on-device agents go.

和訳(チェック用): 動画エディタに「犬が出てくる瞬間を探して」と言うと、
端末内の索引が 12–19 秒と答え、AI がそこへジャンプし、タイムラインを
その 7 秒に切り詰めて書き出す。完全オフライン: オンデバイスモデル+
OS 自身のビジョン。オンデバイスエージェントがどこまで行けるかのサンプル。

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

### B. iPhone voice take — the flagship (user shoots)

Footage: **journey.mp4** (25 s, four scenes: street → forest path →
beach puppy → sunset skyline; built with takekit/concat.swift from
Pexels 2675512 / 4729779 / 853936 / 28320907). Its cuts are at
**6.08 / 12.17 / 19.25 s** of 25.33 s total (ffprobe scene detect), so
the dog scene is 12.17–19.25 s and a correctly scene-snapped keep_range
is ~12–19 → a 7 s clip: the take's own arithmetic, checkable without
the app. Scouted clean on the Mac lane 2026-08-21, EN four beats
end-to-end; JA hits the index through the detector-noun aliases.

1. AirDrop journey.mp4 to the phone, save to the camera roll **last**
   (the app loads the newest library video).
2. Build the LFMTools iOS target to the device (Xcode Beta 5), scheme
   arguments: `--scenario moments --voice --autorun --backend apple
   --without check_moment`. First launch fires the Photos / mic /
   speech permission prompts — accept before the take.
   **The take's room has no check_moment, and that is a product
   ruling, not a hidden edit.** The pack's own design note already says
   the check is the long tail and never the stop condition of anything;
   what the rounds added is that it is the single largest retake risk.
   It vetoes retrieval (beat 1 hedged 「見つかりません」 in run 1 of the
   12 scouts, against its own search hit, with a spurious index sweep
   and a spurious set_clip_speed behind it), and the ritual that calls
   it has a floor no wording has moved: 18–19 of 46 cases across three
   rounds and two binaries. A four-beat take asks nothing about one
   frame, so the tool earns nothing and costs takes. The line this
   stays on the right side of: the bench keeps all 24 tools and keeps
   scoring the ritual honestly — what changes is the product's tool
   list on this screen, not the world, the index, or a result.
3. Speak the four beats. EN: "Find the moment the dog appears." /
   "Jump to that moment." / "Keep only that moment." / "Export it."
   **Three beats, not four** (revised 2026-08-21 after the nine-run
   measurement): beat 1 now performs the jump itself in 9 of 9 runs —
   `search_frames` then `seek` — so a separate jump beat is a beat with
   no visible change, which this file's first take rule forbids. The
   found-it shot still happens; it happens on the sentence that asks
   for it. The four-beat arc stays canon for anything where the model
   does *not* pre-seek; check the log before assuming which room you
   are in. The one run whose beat-1 seek ran on to the scene's tail
   (19 s) was a coin: nine fresh runs put every beat-1 seek on the cut
   at 12 s, and none of the nine made a spurious call of any kind.
   EN: "Find the moment the dog appears." / "Keep only that moment." /
   "Export it."
   JA:「犬が出てくる瞬間を探して。」/「その瞬間だけ残して。」/
   「**エクスポートして。**」
   **Beat 4 was the wobbly one, and it is the money shot.** Bare
   「書き出して。」 routes away from export; 「動画を書き出して。」 was
   the fix, and it missed too — 12 scouts, 2026-08-21: control 2/3,
   the miss calling `auto_captions`, getting "could not transcribe",
   and then refusing to export at all (「動画の音声が認識できません
   でした」). 書き出す sits one character from 書き起こす, which *is*
   transcription, so the verb points at the caption tool as readily as
   at export. Three replacements went 3/3 each — 「エクスポートして。」,
   「動画ファイルとして書き出して。」,「この動画を保存して。」 — and
   the take takes the katakana one: it is the shortest (the voice-sized
   rule) and the only one carrying no 書き出す at all. The general
   rule, worth more than the wording: **when a verb has a near
   neighbour that names another tool, replace the verb or give it a
   noun to land on.** Both repairs worked; only the bare verb failed.
   EN "Export it." has never missed. Beat 3 landed keep_range 12–19 →
   7 s in all twelve runs, both languages — the arc itself is solid.
4. Record via QuickTime device mirroring. Retries per the playbook
   rule. The old JA wart (beat 1 hedging after a boundary check
   misfire) is gone with the check — 0 of 9 — and a bigger one took
   its place: **the JA take answers in English.** Five of six JA runs
   put an English bubble on a Japanese sentence, against 8 of 12
   answering in Japanese when the check was still in the room. On a
   voice take the bubble is the entire muted narrative, so this is now
   the JA take's main retake cause. The ruling — the answer's language
   is the *stage's* contract, not the pack's, carried by a stage-only
   line never added to `ToolBox.momentsInstructions`, which the bench
   shares and must stay the control — was right about the slot and
   wrong about the sentence. **In English it does nothing (1 of 11).
   The same sentence in Japanese takes the JA take to 6 of 10**, and a
   31-run A/B says why: what the model follows is the language the
   instruction block is *written in*, not its content and not its
   distance from the turn. All four conditions said the same thing; the
   identical Japanese sentence appended one line under the beat text
   moved nothing (0 of 5), while in the preamble it moved more than
   half. Both position and language are load-bearing, neither alone
   does anything, and the margin repeated exactly across two batches in
   one sitting (A 0/5 then 0/5, B 3/5 then 3/5; Fisher one-sided
   p = 0.021 against A, 0.002 against the other three pooled).
   The committed line is 「リクエストと同じ言語で回答してください。」
   **English is the attractor, and the effect is asymmetric**: an
   English preamble overrides a Japanese request, while a Japanese
   preamble does not override an English one — the EN take answered
   English 3 of 3 under the Japanese line, which is why it was safe to
   commit. Measured on the moments pack only; if another pack's EN take
   ever answers Japanese, this line is the first place to look.
   6 of 10 is a move, not a solved take: 4 JA takes in 10 still need a
   language retake, and the earlier correlation nobody designed (8 of
   12 Japanese with check_moment in the room, 1 of 6 without, twice)
   still has no mechanism behind it.
   That shared instruction text still names check_moment even where
   the take's room has none; leave it, and read a take's first log line
   (`TOOLS 23 — without check_moment`) for what the room actually held.
5. The Mac take (moment-seek-real-demo.mp4) demotes to the thread's
   second tweet — the "how" shot.

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

### D2. A check that cannot read the question must not veto

Ruled 2026-08-21 after r38 measured the JA mirrors. Two gaps, one
mechanical and one that needed a decision:

1. **Mechanical**: はい/いいえ is a yes/no pair and 「いいえ」 is not in
   the negation marker list, so the pair reads all-positive, falls to
   "none of those", and the model says the thing is not present.
   Partition it — both checks, textually parallel, as ever.
2. **The decision**: `contentWords` splits on non-letters, so a
   Japanese question is one token and can never match an English
   label. The presence test is therefore blind to every JA noun outside
   the 犬/猫 alias table — and being blind, it answers *no*. Growing the
   alias table until it covers a language is the wrong shape; the right
   one comes from this file's own two heuristics (verification vetoes
   retrieval; answers follow the verdict word): **when the check cannot
   evaluate the question — no direct option match, and no content word
   of the question survives into a form the truths could contain — it
   must not return a negative verdict.** It says it cannot tell, and
   lists what the frame shows. The model then falls back on the search
   hit it already has, which is the correct behavior; a confident *no*
   from a tool that never read the question is the failure mode the
   whole take-lane keeps rediscovering. This generalizes past Japanese:
   it is the same answer for any question about something the OS shelf
   cannot name.

**Measured after the fact (r39, three scouts).** The ruling is right
and nearly untestable from the bench: replaying every check call of r38
and r39 through both matchers changes exactly one verdict, and the
cannot-evaluate branch fired **zero times in 20 calls** — the model
writes its check questions in English even on JA cases (16 of 20), and
its JA ones carry timestamp options whose digits make the presence test
runnable. The branch lives on the real index, where a JA question meets
an English label shelf; there the 犬/猫 alias defeats it on purpose by
injecting "dog". Two things it does not cover, both open: a question
whose only surviving content word is a wrapper noun ("scene") still
returns a *correctly evaluated* wrong no, and the 3-character floor in
`contentWords` drops short acronyms the truths do hold ("PK") — the
search tokenizer keeps a 2-char token when it carries a digit, and the
two tokenizers should agree.

And the beat-2 worry was a coin, not a rule: `split_clip` did not
recur in any of three scouts (two JA, one EN), all of which ran
seek 12 → keep_range 12–19 → 25.3 s becomes 7 s. Nothing to reword
there — which is the aggregate-vs-coin rule catching its first live
case.

### E. The CLIP rung (model repo lane)

Embedding index behind search_frames for everything the label shelf
cannot name: index time = frame embeddings at the same ≤90 samples;
query time = text embedding of the model-expanded phrase; hit = cosine
over threshold, rendered as the same Row shape. Then the measurable
A/B the ROADMAP promises: labels-only vs labels+CLIP hit rate on the
same footage set, same beats. This is where "find the goal" starts
working on footage with no scoreboard.

**Readiness, corrected 2026-08-21 (user) — the rung is a dependency
line, not a model project.** An earlier audit here searched the local
disk, found no CLIP weights, and wrote that the weights were the lane's
first step. That was wrong, and wrong in the way this repo's own rule
warns about: absent from *this disk* is not absent. The weights are
published, converted by us, on Hugging Face —
`mlboydaisuke/clip-vit-base-patch32-CoreAI-official` (fp16 static
.aimodel + tokenizer.json, 305 MB), plus
`mlboydaisuke/CLIP-ViT-B32-ExecuTorch` (both towers as .pte, CoreML and
XNNPACK variants) and `mlboydaisuke/clip-vit-b32-litert` (image encoder
.tflite with *precomputed* label embeddings — classification shape, no
runtime text tower, so not the one for free-text queries).

The CoreAI bundle is the one to use, and it is already the exact shape
`coreai-kit`'s `ImageTextEncoder` consumes — that class **downloads
this repo itself**:

```swift
let encoder = try await ImageTextEncoder()
let v = try await encoder.encode(text: "a dog on the beach")
```

One graph carries both towers: inputs `pixel_values` [1,3,224,224] and
`input_ids`/`attention_mask` [3,77]; outputs `image_embeds` [1,512] and
`text_embeds` [3,512], both L2-normalized, so cosine is a dot product
and the text side is *batched three at a time* — size the
model-expanded prompt set to that. The export deliberately pads text to
the full 77-token context so free-text queries work, which is precisely
the half that was called "usually missing". ~3.7 ms per image on the
ANE (M4 Max, fp16); needs iOS 27 / macOS 27, which is already this
app's floor, and the CoreAI framework is absent from the Simulator SDK,
so this rung is device-and-Catalyst only.

So the order is: (1) add CoreAIKit as a package dependency to
lfm-tools-ios (it has none today), (2) prove `ImageTextEncoder` on one
journey.mp4 frame, (3) wire it behind `search_frames` at the same ≤90
samples and run the A/B. Vision's feature print remains no shortcut: it
compares image to image only.

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
- **A tool that answers gets called more; the ritual feeds on
  usefulness.** Teaching the canned check to answer instead of refusing
  (spec C) doubled its own call rate — 7 calls in 7 cases became 15 in
  14, reproduced exactly across two runs — and most of the new calls
  verify a search that had already succeeded. The stop contract did not
  move. **The plateau then stayed up**: 19/20, 18/20, 18/20 across
  r39/r39b/r40, three rounds and two binaries, against r35's 7/7. A
  ritual's floor is a property of what the room offers, and it ratchets
  — it did not come back down when the check got no further help. So
  the lever is not a better answer; it is leaving nothing there worth
  having, or removing the tool from the room.
- **The reply follows the language the instruction block is written
  in — not the request's, not the nearest turn's.** 31 runs, four
  conditions saying the same sentence: English preamble 1/11 Japanese
  replies to Japanese requests, Japanese preamble 6/10, the identical
  Japanese sentence appended per turn 0/5. Content is not the lever and
  proximity is not the lever; the preamble's own language is. The
  effect is asymmetric — English in the preamble suppresses a Japanese
  reply, Japanese in the preamble permits but does not force one (an
  EN take under a JA preamble stayed English 3/3). For a lane that
  ships in two languages: write the preamble in the language the take
  speaks, and re-measure the other language before shipping it.
- **The guardrail is a coin too, not just a verb.** 「犬が出てくる瞬間
  を探して。」 tripped Apple FM's safety filter once in 31 runs of the
  same sentence — and that take exported the untrimmed 25.3 s. A beat
  vocabulary that cleared the rail 30 times can still lose one; check
  the exported duration with ffprobe rather than the toast, on every
  take you intend to ship.
- **Removing the tool does not remove the ritual: the answering slot
  refills.** Taking check_moment out of the take's room ended every
  harm it caused — beat 1 denying its own search hit went 3/12 → 0/9,
  index sweeps 2/12 → 0/9 — and beat 1 immediately grew a `seek`
  instead, in 9 of 9 runs, where none
  of the 12 runs with the check present had seeked there. The model
  does not want *that tool*; it wants something to do after an answer.
  Design for where the slot refills, because it will. (One stray does
  *not* belong to the room and was nearly miscredited: `set_clip_speed`
  vanished from the take runs too, but r41's failure dump shows it in
  three JA bench cases with the check present — it is a JA-input stray
  of the model's, not something the ruling bought. Before crediting a
  change to your change, look for it where your change was not made.)
- **The aggregate belongs to the config; the case list is a coin.** Two
  runs of one config scored identically on the old 40 and made the same
  number of check calls — while 7 of those 40 flipped verdict and 3 of
  14 ritual cases swapped identity. Never read one case's flip as a
  change; never report a round without saying it is one run.
- **The model does not translate the query — measured, twice.** 29 of
  37 search calls on JA inputs carried JA strings, and the 8 English
  ones copied a Latin or numeric token straight out of the request
  (PK, FULL TIME, 0-0). A bare 「雪」 went to the index as 「雪」. Every
  real index needs its own alias table for the nouns a take can utter;
  the findability rule is not a canned-world convenience.
- **Detector rows start late — snap them to the scene boundary.** The
  animal detector first fired ~2 s after the cut that opens the dog
  scene, and the seek visibly missed the scene's head. "The moment" a
  person means is the scene containing the detection: walk the row
  start backward while the classifier's scene signature still matches
  (Jaccard ≥ 0.5), capped at 4 s. The find→**jump**→cut→export arc is
  the canonical four beats now — the jump is the "found it" shot, and
  it must land on the cut, not on the detector's first confident frame.
