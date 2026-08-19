# Video editing — a CapCut's menu, said out loud

The first market-in pack: the tool set is the feature list of an editor
millions already use (trim, split, speed, crop to 9:16, caption, fade,
stabilise, volume, export), in the words its menus use, on the newest video
in the library. The model never sees a frame. **State in, tools out**: every
message opens with the app's state — the clips on the timeline with their
times, which one is selected, where the playhead is, the frame size — and
the tools take the numbers it names. Tools: `ToolBox.video`, 12
(`Tools/VideoEditTools.swift`). Launch:
`--autorun --backend apple --scenario video`; `--voice` for spoken beats.

Not yet run — the phone was in use. Written so the first run answers it:
`run.log` carries `VIDEO loaded — <state>` once, then per beat `STATE`
(the block the model read), `TOOL` (what it called and what came back).

| beat | say | expect |
|---|---|---|
| 1 | Cut the first two seconds, make it vertical, and fade out at the end. | `trim_clip(start, 2)` → `crop_video(9:16)` → `add_fade(out, ~1)` — three menu items out of one sentence; the frame on stage turns portrait |
| 2 | Split it at the playhead. | `split_clip(seconds: <the playhead in the state>)` — the state test: the number is in the message, not in the words |
| 3 | Make the second clip slow motion. | `select_clip(2)` → `set_clip_speed(0.5)` — a two-call chain; clip 2 stretches on the timeline |
| 4 | Caption it 'Tokyo, August' at the bottom for the first three seconds. | `add_caption(text, bottom, 0, 3)` — the frame jumps to the caption |
| 5 | Mute it. | `set_volume(0)` |
| 6 | Export it. | `export_video` — renders through the same composition, saves to the library |

日本語版(未実測):

| beat | 言う |
|---|---|
| 1 | 最初の2秒を消して、縦動画にして、最後をフェードアウトして。 |
| 2 | 再生ヘッドの位置で分割して。 |
| 3 | 2つ目のクリップをスローモーションにして。 |
| 4 | 最初の3秒間、下に「Tokyo, August」とキャプションを入れて。 |
| 5 | 音を消して。 |
| 6 | 書き出して。 |

What the model reads (one line, ahead of the words, every beat):

    [App state] Timeline: 1 clip, 12.4 s total, frame 1920×1080 (landscape).
    Clips: clip 1: 0–12.4 s (selected). Playhead: 5 s.

    Cut the first two seconds, make it vertical, and fade out at the end.

After beat 3 it reads `Timeline: 2 clips, 15.8 s total, frame 606×1080
(portrait, 9:16). Clips: clip 1: 0–5 s; clip 2: 5–15.8 s at 0.5× speed
(selected). Playhead: 5 s. Applied: fade out 1 s.` — the model is told what
its own calls did before it is asked for the next one.

Design

- **The state is the input.** Seconds with one decimal, never `m:ss` — the
  model copies these into arguments and "4.9" survives that better than
  "0:04.9". The playhead is set by the app at load (40 % in) and no edit
  moves it: it is a number the model is asked to copy back, and it stays put
  in timeline coordinates the way an editor's playhead does when the content
  under it changes. The instructions say it plainly: take times from the
  state, never guess one (`ToolBox.stateInstructions`).
- **The menu's words.** `trim_clip(edge, seconds)` because "cut the first
  two seconds" is how people say it; `split_clip(seconds)` because "at the
  playhead" is a number in the message; `select_clip` then act, because that
  is what a tap on a clip does; `crop_video(9:16)` because "vertical" and
  "Reels" both mean that ratio; `add_fade(in|out|both, seconds)`;
  `set_volume(0)` for "mute". `revert_to_original` shares its name with the
  photo pack on purpose — same phrase, never the same session.
- **The edit is real.** An `AVMutableComposition` rebuilt from the clip list
  on every change (insert per clip, `scaleTimeRange` for speed), a Core
  Image video composition for crop / captions / fades / the stabiliser's
  crop-in, an `AVMutableAudioMix` for volume and audio fades,
  `AVAssetExportSession` to write it out. The stage renders the frame at
  the moment the last edit touched (start after a trim, the cut after a
  split, half-dark inside a fade-out, the caption in its window) through
  the same composition — what is on screen is what would export. Under it,
  the timeline: clips as blocks over a filmstrip, the selected one outlined,
  captions as a bar, the shown moment as a line.
- **Stabilise is the honest stand-in.** iOS has no post-hoc stabiliser to
  call; the tool records the level and applies the crop-in a stabiliser
  costs (4 / 8 / 14 %), and says so in its result. The call is what the pack
  demonstrates.

When the phone is back (what to read in `run.log`)

- `VIDEO loaded — Timeline: 1 clip …` proves the library video loaded and
  the state line has the right shape. `VIDEO load failed` means no video in
  the library or the permission was refused.
- Beat 2's `TOOL split_clip` argument must equal the `Playhead:` number in
  that beat's `STATE` line — that is the pack's claim.
- Portrait source: the state must say `1080×1920 (portrait)`, and the frame
  on stage must be upright. If it is sideways, the CI video composition is
  not applying `preferredTransform` and the crop maths are wrong with it.
- After beat 1 the frame on stage must be portrait (606×1080 from a 1080p
  landscape source). If it is landscape, `renderSize` on the CI composition
  is being ignored.
- Beat 6 must leave a new video in the library; open it: cropped, faded at
  the end, muted, captioned in its first three seconds. Delete it before
  the next take — it becomes the newest video.

Recording notes: the prop is the newest library video, ~10–20 s, landscape,
with sound (beat 5 has to have something to mute), some motion (beat 3's
slow motion has to read). Beat 6 saves a copy — delete it before the next
take.
