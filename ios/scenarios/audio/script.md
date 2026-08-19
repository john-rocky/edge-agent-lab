# Audio — a GarageBand mixer, said out loud

The third market-in pack: the mixer of a music app, in its own words, over
four tracks the phone synthesizes itself (drums, bass, keys, lead — a
I–vi–IV–V loop; no audio assets in the repo) and plays through an
AVAudioEngine graph: player → effects → per-track mixer → main mixer. Track
volume and pan, mute and solo, an effect on a track, duplicate and delete,
tempo, a fade, play / stop, export. State in, tools out again: every
message opens with the track list as it is — names, levels, pans, effects,
what is muted or soloed, the tempo, whether it is playing — so "a bit
quieter" is a number the model reads (70) and lowers, and "the keys" is a
track that exists. Tools: `ToolBox.audio`, 16 (`Tools/AudioTools.swift`,
with `set_song_length` in bars). Launch:
`--autorun --backend apple --scenario audio`; `--voice` for spoken beats
(the phone will be playing while you talk — say it between bars). The
mixer is on stage the whole run (`MixerBoard`): a fader per track,
visibly at its level — when the model turns the keys down, the fader
moves.

Routing: **32/36 on Apple FM via the Mac lane** (2026-08-19); not yet
run on the phone (sound itself is a device-day check). What those runs
taught (fixes in): as `percent`, "turn them down a bit" arrived as **5**
— a step, not a fader position; renamed `level` ("where the fader ends
up") — the argument's name is part of the contract. "Fade out at the
end" pulled in `set_song_length` until the two descriptions stopped
sharing the word "end"/"runs".

| beat | say | expect |
|---|---|---|
| 1 | Play it from the top. | `play(from_seconds: 0)` — the loop starts; the state now says "playing at N s" |
| 2 | The keys are a bit loud — turn them down a bit. | `set_track_volume(Keys, ~55)` — 70 read from the state, about 15 off; the keys drop under the mix |
| 3 | Put some echo on the lead. | `add_effect(Lead, echo)` — the graph rebuilds mid-song, the lead repeats |
| 4 | Solo the drums. | `solo_track(Drums, true)` — everything else falls silent |
| 5 | Un-solo the drums, and pan the bass a little left. | `solo_track(Drums, false)` → `set_track_pan(Bass, ~-30)` — a two-call chain |
| 6 | Fade out at the end, then export it. | `add_fade(out, ~2)` → `export_song` — an .m4a in Documents, rendered offline through the same graph |

日本語版(未実測):

| beat | 言う |
|---|---|
| 1 | 最初から再生して。 |
| 2 | キーボードがちょっとうるさい。少し下げて。 |
| 3 | リードにエコーをかけて。 |
| 4 | ドラムをソロにして。 |
| 5 | ドラムのソロを解除して、ベースを少し左に振って。 |
| 6 | 最後をフェードアウトして、書き出して。 |

What the model reads (ahead of the words, every beat):

    [App state] Song: 4 tracks, 8 bars at 110 bpm (17.5 s), stopped.
    Tracks: 1 Drums: volume 80, pan center; 2 Bass: volume 75, pan center;
    3 Keys: volume 70, pan L25; 4 Lead: volume 65, pan R30.

    Play it from the top.

Design

- **Numbers to move, not to invent.** The volume guide names the fader
  position ("where the fader ends up, 0–100; 'a bit quieter' means about
  15 below" the level in the state) — the rail recipe applied to a fader:
  without a reference the model answers 0, 100, or a step like 5.
- **Tracks by what the user calls them.** `track` is a string: a name
  ("Keys"), a number ("3") or the instrument ("keyboard" contains "key").
  The app resolves it; the model does not need an id.
- **Mute vs solo, add vs remove** are the axes; `mute_track(track, muted:
  Bool)` and `solo_track(track, solo: Bool)` are booleans on purpose — a
  bench axis of its own (the case format scores booleans as "true"/"false").
- **The audio is real.** Four loops synthesized at the song's tempo, one
  AVAudioPlayerNode each, effects as AVAudioUnit nodes (reverb, echo =
  delay, distortion, lowpass = EQ), volume/pan/mute/solo on per-track
  AVAudioMixerNodes live; a structural change (effect, track, tempo) rebuilds
  the graph from where the song is. Song fades ride the main mixer while
  playing and are baked in on export (offline manual rendering to .m4a).
- **On screen**: every change posts a table — track / vol / pan / fx / state
  — the mixer as a list. The card under the answer is the view.

Bench: 16 EN + 16 JA in `cases.json`, each with the `state` block it is
scored against (stopped, nothing changed / playing with drums soloed and
echo on the lead). `SCENARIO=audio ./run-device.sh` (toolset `audio`).

When the phone is back (what to read in `run.log`, and hear)

- Beat 1: sound from the speaker within a second of `TOOL play`. Silence
  means the AVAudioSession category or the graph; the tool's own result
  says "could not start playback: …" if the engine refused.
- Beat 2's `percent` must be lower than the 70 in that beat's `STATE`, and
  not 0 — that is the pack's claim about levels.
- Beat 3: the lead audibly repeats after `TOOL add_effect`; the rebuild
  should not click or restart from the top (it resumes from the playhead).
- Beat 6: `mix-<ts>.m4a` appears in the app's Documents; play it in
  Files — the fade is in it.
- Volume of the recording: the stage's own audio is what the screen
  recording captures; keep the phone at a normal level.
