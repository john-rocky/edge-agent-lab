# edge-agent-lab — design (screen → local VL → tap point → tap → loop)

Status 2026-08-15: **all four phases work on device.** A Pixel 8a takes a
screenshot, a local VLM says where to tap, an accessibility service taps there,
and the loop repeats until the screen stops changing. Nothing leaves the phone.
3B int4 on CPU, 11–23 s per step (11.5 s median for one grounding call on a
warm engine).

Two things had to be fixed to get there. A runtime defect showed the model only
the top quarter of any screenshot — fixed on the conversion side (3B: 2/10 →
10/10, matching the torch control). And this app was sending the text content
part before the image; on device that silently destroys localization while
leaving description intact. Both are written up in [FINDINGS.md](FINDINGS.md);
build and run instructions are in [app/README.md](app/README.md).

Naming note (updated 2026-08-18): the side-project gate turned out to cover
the litert-compat lane only, so this repo is public. The `litert-` prefix
stays unused here.

## What the demo is

Take a screenshot of the phone, ask a local VLM where to tap in plain language,
draw the answer on the screen. No network. The whole point is that the model
that understands the screen is the same size as a photo of it.

**Phase 2** (2026-08-15): "Point to the Notifications row" → `[500, 563]` → a
real tap → Settings navigated to `com.android.settings/.SubSettings`. 22.7 s per
step, one screen-capture consent for the whole session.

**Phase 2.5** — a goal instead of a target. "open the notification history"
reached Settings → Notifications → Notification history in two taps; the third
step found nothing new and the screen-change guard stopped the loop.

**Phase 3** — the middle is a Kotlin library, `//sdk:screen_agent`
(`com.edgeagent.sdk`), and the app is its host. The extraction was an
extraction: the seams named below were already the file boundaries, so nothing
had to be rewritten to pull them out. See [sdk/README.md](sdk/README.md).

## The pipeline

```
ScreenSource ──▶ Framing ──▶ Grounder ──▶ Mapping ──▶ ActionExecutor
 MediaProjection  fixed point  VLM+prompt   norm→px      tap
       ▲                                                  │
       └──────────────── Agent, until nothing changes ─────┘
```

Five seams. Three are interfaces the host fills (`ScreenSource`, `Grounder`,
`ActionExecutor`); `Framing` and `Mapping` are pure code the library owns.

| component | responsibility | why it is its own seam |
|---|---|---|
| `ScreenSource` | one `Bitmap` of the current screen | MediaProjection consent + foreground-service lifecycle is Android policy churn; nothing else should know about it. The SDK takes the interface, the app supplies `CaptureService` |
| `Framing` | screen bitmap → one or more model-sized views + the transform back | the only place that knows the runtime's resolution limits; see below |
| `Grounder` | view + instruction → `List<Grounded>` | swappable model/runtime — `LiteRtGrounder` is one implementation; the prompt and parser are a fixed vendor contract |
| `Mapping` | normalized `[0,1000]` → screen px, through the framing transform | pure function, unit-testable, the part most likely to be silently wrong |
| `ActionExecutor` | dispatch a tap — `AccessibilityExecutor` over `TapService` | accessibility service, separate permission the user must grant by hand, separate process concerns |

`Grounded` is the whole data contract between them:

```kotlin
data class Grounded(
    val label: String,
    val point: Point?,      // normalized [0,1000]
    val box: Rect?,         // normalized [0,1000]
    val imageId: Int,
)
```

Keeping coordinates normalized all the way to `Mapping` is deliberate: it is the
model's native output unit, it survives tiling and rescaling, and it makes the
one risky step (framing transform) a single named function.

## The grounding contract is not ours to invent

The system prompt and the output schema are fixed by the vendor's own demo
(`huggingface.co/spaces/LiquidAI/LFM2.5-VL-3B-WebGPU`, `src/main.js` +
`src/grounding.js`). Both are reproduced verbatim in `tools/ground_probe.py`;
the Kotlin side must match them byte for byte, not paraphrase them.

Output, confirmed emitted by the LiteRT-LM runtime on the first try:

```json
[{"image_id": 0, "point_2d": [500, 559], "label": "Notifications"}]
```

Coordinates are integers in `[0,1000]`, `[x,y]` for points and
`[xmin,ymin,xmax,ymax]` for boxes. The vendor parser also accepts `0..1` floats
and bare arrays in prose; ours does too.

## Framing: the component the runtime forced into existence

The runtime resizes an image preserving aspect ratio to at most 1024 patches of
16 px (`GetAspectRatioPreservingSize`, snapped to multiples of 32) — no crop, no
padding. A 1080×2400 screenshot becomes 320×736: about 10 px per line of
settings text. Two consequences:

1. **Mapping is a plain linear per-axis scale.** No letterbox arithmetic, no
   offset. Verified end-to-end by the torch overlay (10/10 on real targets,
   including a 92×41-px Wi-Fi icon).
2. **One whole-screen view is too coarse to be the plan.** Tiling into
   native-aspect square views (1080×1080, ~10% overlap, 3 tiles for a 2400-tall
   screen) gives each tile a 2.1× rather than 3.4× downscale, and matches what
   the vendor's own processor does at native resolution.

So `Framing` is a real component with a real decision in it, not a resize call.

The shipped choice is to emit **the fixed point of the runtime's own sizing
function** — iterate `GetAspectRatioPreservingSize` until it maps a size to
itself. A 1080×2400 screen converges to 320×768 in two steps. The runtime's
resize then returns early, so there is one resample instead of two and the image
the engine sees can be reproduced exactly off-device (pull `cache/view.png` and
run it through the desktop CLI). Verified: the repaired 3B scores 10/10 on the
battery at full 1080×2400 and gets every target right at 320×768.

Tiling stays unbuilt. A single whole-screen view resolves Settings-sized targets,
including a 92×41-px Wi-Fi icon, so tiling is an accuracy dial to turn if denser
screens miss — not a requirement. `Framing` stays a seam because that
measurement has not been done on denser screens yet.

## Demo configuration

**LFM2.5-VL-3B int4 + fix B, CPU backend, single whole-screen view.** ~24 s per
turn on a Pixel 8a; engine load 9–24 s with warm caches.

Three constraints forced this, none of them preferences:

- **3B or nothing.** Grounding coordinates are a 3B-only capability in this
  family. The 450M and 1.6B emit round numbers (0/100/200/500) for every target,
  repaired or not, which matches ScreenSpot-v2 80.7 being published for the 3B
  alone. There is no small-and-fast option.
- **CPU, not GPU.** The 3B on the GPU backend kills the app process during
  engine init on this 8 GB device. The engine cascade still tries GPU first and
  falls back, so the split that works for smaller models (text-GPU +
  vision-CPU — the SigLIP2 encoder does not compile on the Pixel GPU delegate)
  is still there for them.
- **Budget the disk.** The 3B bundle is 2.35 GB and leaves 3.9 GB of compile
  caches behind. The 1.6B leaves 172 KB.

## Two traps that cost a day

Both are in FINDINGS.md in full; they belong here too because they are design
constraints, not incidents.

1. **Image content part before text.** `Content.Text` then `Content.ImageFile`
   describes the screen perfectly and cannot locate anything on it. The desktop
   CLI puts attachments first, which is why desktop controls never showed it.
2. **The runtime showed only the top quarter of any image** until the vision
   pair was re-exported with the pooling moved into the encoder.

Neither raises an error. Both produce well-formed, plausible output. Any change
to framing, prompt assembly, or the bundle needs the `fixtures/rows16.png` ruler
and at least two targets at different heights before it is believed.

## Harness (built, working)

| file | what it does |
|---|---|
| `tools/ground_probe.py` | screenshot + ground-truth boxes → runs the `litert-lm` CLI per target, parses the vendor JSON, scores hit/miss, renders an overlay PNG |
| `tools/hf_ground_ref.py` | the same battery through torch/HF — the control that separates "model can't" from "runtime won't" |
| `tools/make_grid_fixture.py` | synthetic 2×2 labelled-button fixture + ground truth |
| `fixtures/settings_pixel8a.json` | 10 hand-labelled targets on a Pixel 8a Settings screen, including one small icon and one indirect-intent query |
| `fixtures/rows16.png`, `rows8.png`, `cols8.png` | visibility rulers — numbered bands/columns that report exactly how much of an image reaches the model |
| `tools/reexport_vision_unshuffle.py` | fix B: re-exports only the vision pair with the pixel-unshuffle moved into the encoder (monkey-patched, so the installed `litert_torch` is untouched) |
| `tools/repack_vision.py` | swaps two vision sections into an existing bundle and repacks, carrying the shipped text quantization over byte for byte |

The rulers are worth keeping permanently: they are a 12-second check that a
runtime, backend, or bundle actually sees the whole picture, and they would have
caught this defect at conversion time.

## Phase 2 as built

One consent, then a loop. `CaptureService` holds the MediaProjection for the
whole session and serves frames on demand — the consent *token* is single-use on
API 34+, the projection it creates is not. Without that, every capture reopens
the system dialog and there is no agent loop to speak of.

A run is: background the app → capture → ground → tap → wait → capture again →
draw the marker on the screen the tap produced. Showing the *after* frame with
the marker still on the pressed point is the demo; a point alone proves nothing
about whether the tap landed.

`grab()` waits for the next frame rather than reading the buffered one. After a
tap the buffered frame is the screen from before it, which would make every run
look like a no-op.

`TapService` deliberately does not declare `canRetrieveWindowContent`. The lane's
claim is that the screen is understood by the model, not read out of the
accessibility tree — taking the tree would undercut the whole point.

## The agent loop

`Agent.kt` takes a goal and drives capture → ground → tap until it stops. It is
handed `capture`, `ground`, `tap` and `settle` as functions, so it has no Android
dependency beyond `Bitmap` — which is why it moved into the SDK unchanged.

Measured on a Pixel 8a, goal "open the notification history", starting from the
Settings list:

```
1. notification history tapped          Settings  -> Notifications
2. open the notification history tapped Notifications -> Notification history
3. open the notification history tapped (nothing moved)
stopped: the screen did not change - stopping rather than repeating
```

**The stopping rule is the screen, not the model.** The model does not reliably
say "done" — step 3 above is it inventing a target on a page where the goal was
already met, exactly the confabulation recorded in FINDINGS.md. So the loop
compares consecutive frames (32x64 thumbnail, mean absolute luma, threshold 6)
and stops when a tap changes nothing. An empty reply is still honoured as done;
it just cannot be relied on to arrive. Without the frame check the agent would
tap the same dead pixel until the step cap.

## Planning, once tapping is not enough

A tap-only agent can only reach what is already on the screen. The wider action
set — scroll, back, type — needs the model to say *what* to do, not just where,
so `Agent.operate` asks twice per step: a planner call with our own prompt, then
the vendor grounding call, and only when the chosen action needs a coordinate.

Splitting it that way is not an optimisation. The grounding prompt is a fixed
vendor contract; extending it to also carry a verb vocabulary would be
paraphrasing it, which is the one thing FINDINGS.md says never to do. Two plain
questions about the same screen cost one extra call and leave the contract
intact.

Typing is the one action that reaches outside the pixels. Android has no way to
put characters into a field by gesture, so `TapService.typeText` asks for the
input-focused node and sets its text — the accessibility tree as an actuator,
never as a sensor. Nothing in the app enumerates windows or reads node text.
That line is what `canRetrieveWindowContent="true"` buys, and it is worth
stating out loud because the flag looks like the app started reading the screen
the easy way.

## Non-goals

No tool registry. FunctionGemma 270M remains a part candidate, not a dependency.
Long-press, drag, and multi-window are not implemented; each would be one more
method on `ActionExecutor` and one more verb in the planner, and neither the
loop nor the framing would change.
