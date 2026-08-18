# Finding: LiteRT-LM 0.16.0 delivers only the first quarter of an image to LFM2.5-VL

Found 2026-08-14 while building the Phase 1 screen-grounding spike. Everything
below is measured, with a torch control on the same inputs.

## Headline

On the LiteRT-LM runtime, LFM2.5-VL sees **only the top ~25% of any image** as
resolved spatial detail. Content below that line is at best globally sensed and
cannot be located, counted, or listed.

| path | same model, same image, same prompt | score |
|---|---|---|
| HF transformers (torch bf16) | 1080×2400 Pixel screenshot, 10 grounding targets | **10/10** |
| LiteRT-LM 0.16.0 pip CLI, `.litertlm` int4 | identical | **2/10** |

The two runtime hits are the only two targets whose ground-truth box sits above
y=250/1000. The first miss is at y=293. The cut is visible in the raw data.

## Root cause (source- and artifact-verified)

Shapes in the shipped bundle (`litert-lm-peek` on `LFM2.5-VL-3B_int4.litertlm`):

```
tf_lite_vision_encoder   images       [1,1024, 768]  ->  features     [1,1024,1152]
tf_lite_vision_adapter   soft_tokens  [1,1024,1152]  ->  mm_embedding [1, 256,2048]
```

`runtime/executor/vision_executor_utils.cc` (v0.16.0, tag `v0.16.0` =
`924e79c9`) derives:

```
num_tokens_per_image    = adapter output dim[-2]                    = 256
patch_num_shrink_factor = encoder input dim[-2] / num_tokens_per_image
                        = 1024 / 256                                = 4
```

`runtime/executor/vision_litert_compiled_model_executor.cc:583-641` then feeds
the adapter:

```cpp
num_patches = (num_patches_from_input + shrink - 1) / shrink;   // 1024/4 = 256
adapter_input_buffers[0].Clear();
adapter_input_buffers[0].Write<float>(
    absl::MakeSpan(encoder_output_data.data(), num_patches * encoder_output_dim));
```

The adapter's input is 1024 rows. Only 256 are written; the other **768 rows
stay zero**. In patch-raster order the surviving 256 rows are the top 8 of 32
patch rows — the top quarter of the image.

The runtime's assumption is that the *encoder* performs the spatial shrink and
emits `num_tokens_per_image` meaningful rows first. That holds for ViT-style
bundles. It is false for LFM2.5-VL, where the 2×2 pixel-unshuffle lives in the
**adapter** (`multi_modal_projector`) — the encoder emits all 1024 rows and the
adapter pools them. The code comment at `vision_executor_utils.cc:85-93` names
LFM2 VL explicitly as the single-input case the derivation is meant to cover, so
this is an unnoticed wrong assumption rather than an unsupported model.

## Reproduction

```bash
# grid + the three visibility rulers (deterministic; regenerates the committed
# fixtures byte for byte)
python3 tools/make_grid_fixture.py --out fixtures/grid2x2 --rulers

litert-lm run LFM2.5-VL-3B_int4.litertlm --backend cpu --cache no \
  --temperature 0 --seed 0 --max-num-tokens 2048 \
  --attachment fixtures/rows16.png \
  --prompt "The image is divided into horizontal bands, each printed with a number. List every number you can see, from top to bottom. Do not guess numbers you cannot see."
```

Measured (3B int4, CPU, temperature 0):

| fixture | expected | shipped bundle | fix B bundle |
|---|---|---|---|
| `rows16.png` — 16 numbered bands | 1…16 | `1 1 2 2 3 3 4 4` — top 4 only (25%) | *(450M: `1…16`)* |
| `rows8.png` — 8 numbered bands | 1…8 | `1, 2, 1, 2` — top 2 only (25%) | `1…8, 1…8` (both columns) |
| `cols8.png` — 8 numbered columns | 1…8 | `1,2,3,4,5,6,7,8` — full width, no loss | — |
| `grid2x2.png` — 4 labelled buttons | 4 labels | `Settings, Camera` (top row only) | — |
| `grid2x2.png` — "which button is bottom-left?" | Messages | `Settings` | *(450M: `Messages`)* |
| `grid2x2.png` — point to Messages / Photos | a point | `[]` ("none are visible") | — |

450M int4 shows the identical top-4-of-16 cut, so this is family-wide, not a
3B-specific artifact.

Full-width, top-quarter — exactly the raster prefix the arithmetic above
predicts.

## What this retro-explains

`~/code/litertlm-convert/lfm25vl_work/RESULTS.md` closed the 450M/1.6B image-gate
mystery as "remaining suspects live INSIDE the engine (prefill chunk planning ×
ShortConv state with mm embeddings spliced, or embedding-splice details) — not
reachable from outside the runtime". At least part of that mystery is this bug:
the 450M's `circle.png` fingerprint flips from `Square.` to `Circle.` when the
bundle is repaired (measured below), with no other change.

The loss is not a clean crop. Single dominant subjects below the line still read
correctly through the broken bundle (`hello.png` → "Hello.", `cat_dog.png` →
"CAT.", and the 3B still answers "Circle."), because SigLIP2 is a
global-attention ViT: each surviving token carries whole-image context. What
dies is everything positional — locate, enumerate, "which one is bottom-left",
"list all four". Those are exactly the questions an agent asks.

Practical consequence for gating: fixtures that put one dominant object in the
middle of the frame cannot tell a seeing model from a guessing one. **Any future
image gate needs at least one target below the 25% line and at least one
question whose answer depends on position.** `fixtures/rows16.png` is a
12-second version of that check.

## Two fixes

**A — runtime (upstream bug report).** The number of encoder rows to forward
should come from the adapter's *input* shape (1024), not from
`encoder_input_patches / adapter_output_tokens`. Equivalently:
`patch_num_shrink_factor` must be 1 whenever the adapter performs the shrink.
Built and verified — see below.

**B — export/bundle (ours, no runtime patch needed).** Move the 2×2
pixel-unshuffle out of the adapter and into the exported encoder, so:

```
encoder  images [1,1024,768]  ->  features     [1,256,4608]
adapter  soft_tokens [1,256,4608] -> mm_embedding [1,256,2048]
```

Then `shrink = 1024/256 = 4`, `num_patches = 256`, and the 256 forwarded rows
are exactly the 256 pooled tokens the adapter wants. Correct on the released
runtime. The change lives in
`litert_torch/generative/export_hf/model_ext/lfm2_vl/vision_exportable.py`
(`LiteRTExportableModuleForLFM2VisionEncoder.forward` /
`...ForLFM2VisionAdapter.forward`, which currently does
`soft_tokens.reshape((1,32,32,-1))`).

Fix B also repairs every already-published `litert-community/LFM2.5-VL-*` bundle
(3B / 1.6B / 450M) without touching anyone's runtime.

## Fix A: built and verified (2026-08-15)

Patched runtime, **stock unrepaired bundles**. `upstream/fixA-adapter-input-rows.patch`
(31 lines, one function) against v0.16.0 `924e79c9`, built with
`bazelisk build //runtime/engine:litert_lm_main -c opt --enable_platform_specific_config`.

The patch keeps `num_patches` as the count of tokens the adapter *emits* and
adds a separate count of rows it *consumes*:

```cpp
num_encoder_rows = min(num_patches_from_input,   // patches this image really has
                       adapter_input_rows,       // what the adapter can take
                       encoder_output_rows);     // what the encoder produced
```

Three properties made it worth writing this way rather than fixing the shrink
factor:

- **The masked path is untouched.** Where the encoder emits a mask, the mask
  already says how many rows carry an image, so the new code is skipped
  entirely.
- **Encoders that shrink are unchanged.** Their adapter input buffer is the
  smallest of the three, so the `min` returns exactly the old `num_patches`.
- **It cannot overrun.** Both buffer sizes bound the write, which the previous
  expression did not.

Measured, 450M int4 CPU, unrepaired bundle, greedy:

| probe | before | after |
|---|---|---|
| `rows16.png` — list every band | `1 2 3 4 4 4 1 2 3 3 1 2 2 1 1 …` | `1…16` |
| `rows8.png` | `1, 2, 1, 2` | `1…8` |
| `grid2x2.png` — bottom-left button | `Settings` | `Messages` |
| `cols8.png` — full width, was never lost | `1…8` | `1…8` |

3B int4 CPU, **unrepaired** bundle, vendor grounding prompt, Pixel 8a Settings
screenshot — the numbers fix B produces, from a stock bundle:

| target | patched runtime | fix B bundle (2026-08-14) |
|---|---|---|
| search bar | `[500, 99]` | `[500, 99]` |
| Notifications | `[500, 551]` | `[500, 551]` |
| Storage | `[259, 981]` | `[558, 981]` |

Storage keeps the x divergence recorded further down; y — the axis the defect
destroys — agrees.

Fix A and fix B are not exclusive. A repaired bundle through the patched runtime
also reads `1…16`, because the `min` collapses to the pooled-token count that
bundle already emits.

**What is still not tested:** a ViT-family bundle (Gemma-3 and friends). None is
on this machine. The argument that they are unaffected is the one above — their
adapter input row count bounds the `min` to the previous value — and it is an
argument, not a measurement.

## Fix B: built and verified (2026-08-14)

`tools/reexport_vision_unshuffle.py` monkey-patches the two exportable modules
(no edit to the installed `litert_torch`) and re-exports **only** the vision
pair; `tools/repack_vision.py` swaps those two sections into an existing bundle
and repacks, so the shipped text quantization is carried over byte for byte.
Whole cycle on the 450M: about 90 seconds.

Shapes, 450M (vision hidden 768, text hidden 1024):

| | before | after |
|---|---|---|
| encoder | `images [1,1024,768]` → `features [1,1024,768]` | → `features [1,256,3072]` |
| adapter | `soft_tokens [1,1024,768]` → `[1,256,1024]` | `soft_tokens [1,256,3072]` → `[1,256,1024]` |

Section sizes barely move (encoder 89,198,064 → 89,199,824 bytes), as expected
for the same graph plus a reshape/permute.

Measured, 450M int4, CPU, temperature 0:

| probe | before | after |
|---|---|---|
| `rows16.png` — 16 numbered bands | `1 2 3 4` (top 25%) | **`1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16`** |
| `grid2x2` — "which button is bottom-left?" | `Settings` (wrong, top-left) | **`Messages`** (correct) |
| `grid2x2` — list every button label | `Settings, Camera` | `Settings, Messages, Photos` |
| `circle.png` — the RESULTS.md 450M fingerprint | `Square.` | **`Circle.`** |
| `count3.png` | `3.` | `3.` (this phrasing already passed) |

The `Square.` → `Circle.` flip is the exact 450M image-gate fingerprint that
RESULTS.md left open as an unreachable engine-internal residual. It is fixed by
a conversion change.

450M grounding coordinates stay useless before *and* after (it emits round
numbers — 0, 100, 200, 500 — for every target, 0/10 then 1/10). That is a
capability limit of the 450M, not the bug: ScreenSpot-v2 80.7 is the 3B's
number. The 450M's role here is the visibility ruler, which it settles
conclusively.

### 3B: the runtime now matches torch exactly

Same cycle on the 3B (`vision_encoder` 419,653,264 → 419,655,024 bytes),
then the same 10-target battery on the same Pixel screenshot:

| path | score |
|---|---|
| LiteRT-LM 0.16.0, shipped bundle | 2/10 |
| LiteRT-LM 0.16.0, **fix B bundle** | **10/10** |
| HF torch control | 10/10 |

```
[hit ] search bar            [[500,  99]]     [hit ] Notifications       [[500, 551]]
[hit ] account row           [[500, 191]]     [hit ] Sound & vibration   [[362, 629]]
[hit ] Network & internet    [[376, 281]]     [hit ] font size (indirect)[[500, 816]]
[hit ] Wi-Fi icon (small)    [[123, 294]]     [hit ] Wallpaper & style   [[349, 880]]
[hit ] Connected devices     [[392, 370]]     [hit ] Apps                [[252, 468]]
```

Including the 92×41-px Wi-Fi icon and the indirect query ("I want to change the
font size" → the Display & touch row). Unchanged runtime, unchanged text
weights — only the two vision sections were swapped.

No regression on the original image gates: the 3B scores 5/5 before and after
(`Red. / Hello. / Circle. / Three. / CAT.`). The difference is that the 5/5 is
now earned rather than partly scored on priors.

Artifacts: `~/code/litertlm-convert/lfm25vl_work/out_fixb/` (both repaired
bundles plus the four quantized vision tflites).

### Confirmed on-device (Pixel 8a, Android AAR 0.16.0)

The 1.6B was repaired the same way (its vision tower and text hidden size are
both identical to the 3B's, so the two exports are byte-for-byte the same size)
and run through the Android app, capturing `fixtures/rows16.png` off the real
screen via MediaProjection:

```
9.1s — 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
```

All sixteen bands. The stock bundle stops at 4. So the defect and the fix both
carry over to the Android AAR exactly as they do on the desktop CLI.

Device timings, 1.6B int4, text-GPU + vision-CPU: engine load 27–30 s (first
load builds XNNPack caches), then 8–9.4 s per capture-and-ground turn. The 3B
int4 on CPU loads in 9–18 s with warm caches and takes 15–22 s per turn.

Cache footprint is very model-dependent: the 1.6B leaves 172 KB behind, the 3B
leaves **3.9 GB** (1.6 GB XNNPack text + 416 MB XNNPack vision, plus 1.5 GB +
413 MB mldrift caches from the GPU attempt). So RESULTS.md's multi-GB cache
warning does apply at 3B scale — budget for it on top of the 2.35 GB bundle.

**3B on the GPU backend kills the app process** during engine init on this
8 GB device — the same outcome the chat app saw with Qwen2-VL-2B. CPU works.

## The Android content-order trap (this was our bug, not the runtime's)

For most of this investigation the Android app returned useless grounding while
the desktop CLI was exact on the same bytes. The cause was the order of the
message parts.

```kotlin
// wrong — describes fine, cannot localize
Contents.of(listOf(Content.Text(prompt), Content.ImageFile(path)))

// right
Contents.of(listOf(Content.ImageFile(path), Content.Text(prompt)))
```

`litert-lm run --attachment` places attachments **before** the first user text
prompt. Every desktop control run therefore had image-first, and every device run
had text-first, which is why the two never agreed.

Flipping the order fixed it outright. Same bundle, same screenshot, 3B int4 on
CPU:

| target | ground truth | Mac CLI | Android, image-first |
|---|---|---|---|
| search bar | ~98 | `[500, 99]` | `[500, 99]` |
| Notifications | ~559 | `[500, 563]` | `[500, 551]` |
| Sound & vibration | ~642 | `[366, 629]` | `[367, 628]` |
| Storage | ~980 | `[158, 986]` | `[558, 981]` |

### Isolated on-device, one variable

The app is not needed to show this. `litert_lm_main` built for Android with an
added `--image_path` / `--image_first` flag, same binary, same bundle, same
image, same prompt file, CPU backend — only the content order changes:

| target | ground truth | `--image_first=true` | `--image_first=false` |
|---|---|---|---|
| search bar | ~98 | `[500, 94]` | `[]` |
| Notifications | ~559 | `[500, 551]` | `[]` |
| Sound & vibration | ~642 | `[362, 629]` | `[]` |
| Storage | ~980 | `[500, 980]` | `[500, 981]` |

**4/4 against 1/4.** No JNI, no MediaProjection, no app code. Text-first is not
uniformly broken — the bottom row still resolves — which is exactly why it reads
as flaky runtime behaviour rather than a wrong call.

### The documentation says to do the broken thing

`agents/skills/create-litert-lm-android-demo-app/references/inference_implementation.md`
in the LiteRT-LM repo, verbatim:

> **Content Order Check**: You MUST add `Content.Text` to the contents list
> BEFORE any media content (like `Content.Image` or `Content.Audio`) to match
> model expectations.

That is where this app's order came from. It contradicts two things in the same
ecosystem: LFM2.5-VL's own model card puts the image content part first, and
`litert-lm run --attachment` places attachments before the first user text
prompt. Following the documented order costs 3 of 4 grounding targets.

### Why it is worth writing down

Text-first is not obviously broken. The model still describes the screen, still
reads every row in order, still echoes the requested label. It only loses the
ability to *locate* anything — the instruction is consumed before the image
tokens arrive, so nothing binds it to a position. Captioning apps will never
notice. Any agent that needs coordinates breaks silently.

The app's original comment said "Content order rule: text before media", copied
from the chat-app build (`inference_implementation.md` §5). That rule is fine for
captioning. It is wrong for grounding, and nothing in the API or the output
signals the difference.

### What the symptoms looked like

Recording these because they read exactly like a runtime defect, and I wrote them
up as one before finding the cause:

- one coordinate per screenshot, returned for every target (`[500, 100]` on the
  Settings screen, `[500, 896]` on the home screen)
- `[]` — "none are visible" — for a row the same model lists as item 5 when asked
  to enumerate
- coarse fallbacks degenerate too: prose "x,y" gave `5, 6`; a 10-band question
  answered `6` for both a top-of-screen and a mid-screen target
- the attractor moved when text activation precision changed (fp16 `[131, 988]`,
  fp32 `[500, 100]`, fp32_fp16 `[135, 985]`), which looked like strong evidence of
  a numerics bug in the runtime

None of that was the runtime.

### Ruled out along the way (all still true, all beside the point)

- **Image** — the device's own `cache/view.png`, pulled byte-for-byte, grounds
  correctly on the Mac.
- **Preprocessing** — the AAR ships the same `stb_image_preprocessor` as desktop
  (skia is opt-in behind a `--define` and absent from the shipped `.so`), and the
  failure survived skipping the runtime's resize entirely.
- **Sampler and KV size** — the Mac is stable with the app's exact settings.
- **Activation precision** — three settings, all degenerate.
- **Prompt wording and length** — compact and verbose forms both failed.

### Two things worth keeping from the hunt

**Feed the runtime a size it will not resize.** `Framing` now emits the fixed
point of the runtime's own sizing function — iterate
`GetAspectRatioPreservingSize` until it maps a size to itself; a 1080×2400 screen
converges to **320×768** in two steps. The runtime's resize then returns early,
which removes a double resample and makes the image the engine sees reproducible
off-device.

**Pin the sampler.** The app now passes
`ConversationConfig(samplerConfig = SamplerConfig(topK = 1, topP = 1.0,
temperature = 0.0, seed = 0))`. A coordinate is three digits; one sampled token
ruins it, and prose hides the problem. This changed nothing here, but leaving it
to the default is a latent bug.

**`prefer_activation_type` is a container-level lever.** It sets activation
precision per section without re-exporting anything:

```bash
litert-lm unpack model.litertlm --output-dir u
# add   prefer_activation_type = "fp32"   under model_type = "prefill_decode"
litert-lm pack u/model.toml --output model_fp32.litertlm
```

### The lesson

Two wrong write-ups preceded the right one, both from too little data — a single
target on a single screen. The rule that would have caught this: **before
blaming a runtime, diff every input, including the ones that feel like
formatting.** Content order looked like style. It was semantics.

### Still open

- Fix A (runtime-side) is now built and measured (2026-08-15); the entry below
  records what was run. Fix B does not
  need it, but upstream probably wants it so that bundles built the ordinary
  way stop being silently wrong.
- The `litert-community/LFM2.5-VL-{450M,1.6B,3B}` bundles on HF are all still
  affected. Republishing is a user decision, not done here.
- A device-side CLI cross-check is still not available: v0.16.0 `litert_lm_main`
  has no image flag, so the AAR is the only on-device image path. Adding one is
  worth doing and worth upstreaming — it would have settled the content-order
  question in one run instead of a day. An Android build of `litert_lm_main` is
  currently blocked on a `rules_rust` failure (`thiserror_impl` not found when
  building an exec-config tool; the same target builds fine for macOS), which is
  the next thing to clear.

## Notes for the demo

- Coordinate mapping is otherwise sound. The runtime resizes preserving aspect
  to ≤1024 patches (`GetAspectRatioPreservingSize`, snapped to multiples of 32)
  with no crop and no padding, so normalized `[0,1000]` coordinates map back to
  screen pixels by a plain per-axis linear scale. Verified by the 10/10 torch
  overlay.
- The vendor grounding contract (verbatim from the official WebGPU demo,
  `src/main.js` / `src/grounding.js`) is reproduced in `tools/ground_probe.py`
  and ported to `app/.../Grounding.kt`. Both runtimes emit exactly that JSON.
- **Put the image content part before the text content part.** See the
  content-order section — this is the single line that decides whether on-device
  grounding works.

## Agent-safety behaviour found while filming Phase 2 (2026-08-15)

Two model behaviours that matter for anything that acts on the answer. Both are
model behaviour, not the device path — the desktop CLI reproduces them exactly on
the same frames.

**It does not say "not visible".** Asked to point at the Chrome icon on a home
page that has no Chrome on it, the 3B answered
`[{"point_2d": [381, 830], "label": "Chrome icon"}]` — the Google Drive icon in
the dock. The tap opened Drive. The vendor prompt explicitly permits `[]`
("Return [] if none are visible") and the model still confabulated. The desktop
CLI returns the identical `[381, 830]` on the same pulled frame, and gets Files
and Google TV on that frame right, so the model is accurate about what is there
and invents a match for what is not.

**Visually similar neighbours are near-missed.** "the camera icon in the bottom
dock" returned `[852, 896]` — the Lens camera glyph in the search bar, one row
below the dock camera at `[852, 829]`. Right column, wrong row by 6.7% of screen
height. It opened Google Lens.

An agent cannot treat a returned point as evidence the target exists. Practical
consequences for the design: verify after acting (capture again and check the
screen changed as expected), and treat the returned `label` as a claim to check
against the request rather than as confirmation. Neither is implemented yet.

Hits on the same session, for balance: Notifications row `[500, 563]`,
Accessibility row `[314, 834]`, Chrome icon `[864, 350]` on the page that
actually has Chrome — all landed and all navigated correctly.

## Planner behaviour, measured while building the action set (2026-08-15)

Adding scroll / back / type meant asking the model *what* to do, not only where.
Four things about a 3B planner showed up on device that nothing on the desktop
would have caught. All were reproduced across runs at temperature 0.

**It copies the prompt's placeholders.** Given a schema written the obvious way —
`{"action": "type", "target": "<the field>", "text": "<text to type>"}` — it
replied `{"action": "type", "target": "<search box>"}`: angle brackets kept, and
the required field simply dropped. Replacing the schema with filled-in examples
fixed the brackets.

**Then it copies the example's values.** With
`{"action": "type", "target": "the search box", "text": "battery"}` as the
example, the goal "type sound into the search box" produced `"text": "battery"`.
It typed the example. One added sentence — *"text" must come from the goal above,
never from the examples* — fixed it: the same goal for "wifi" then typed `wifi`.
Small models read examples as data, not as illustration.

**It invents verbs, and the fallback should press rather than stop.** Asked to
search, it answered `{"action": "search", "target": "the search box", ...}`.
`Planning.parse` treats an unknown verb that names a target as a tap, and that
was exactly right — the run tapped the search box and typed on the next step. An
unknown verb with no target is still a stop.

**"Done" is reliable here, and it is not reliable in the grounding prompt.**
Asked for a point, the model confabulates rather than returning `[]` (above).
Asked to choose an action with `{"action":"done"}` in the vocabulary, it returned
done at the right moment in every run that reached the goal. The stop signal
works when it is one option among five, not when it is the absence of an answer.
The screen-change guard is still the backstop.

### Two device details the loop has to know

**Typing needs the field to be focused, and a tap can take that away.** Android
puts characters into whatever holds input focus, so `type` is not
best-effort — with nothing focused it goes nowhere. The loop focuses the named
field first, *unless* something is already focused: a screen that opens with its
search box focused loses that focus to a grounded tap landing a few pixels off,
and the characters vanish. `ActionExecutor.hasTextFocus()` is what that test asks.

**A scroll through the middle of the screen is glide typing when the keyboard is
up.** The first demo take scrolled `TT` into the search box. With a field
focused the stroke now runs from 50% to 18% of screen height, above the keyboard.

## Which cores the agent actually gets (2026-08-15)

The app puts itself in the background to see other apps, which raises the
question of whether the published per-step number is little-core timing. It is
not, and the prime core turns out to be worth almost nothing here.

The Pixel 8a's cpusets and clocks, read off the device:

| cpuset | CPUs | |
|---|---|---|
| `top-app` | 0-8 | includes the prime core |
| `foreground` | 0-7 | little + mid |
| `background` | 0-3 | little only |

little 0-3 at 1704 MHz, mid 4-7 at 2367 MHz, prime 8 at 2914 MHz.

A foreground service of type `mediaProjection` keeps the process in
`foreground` while its activity is backgrounded — checked with
`cat /proc/$(pidof com.edgeagent.lab)/cgroup` during a run, in every state the
loop passes through. So the agent never falls to the little-core floor, but it
does run without the prime core.

Measured cost of that, same instruction and same warm engine, one grounding call
per sample:

| state | samples | median |
|---|---|---|
| `top-app` (activity on screen) | 17.5, 11.3, 11.3 s | 11.3 s |
| `foreground` (activity backgrounded) | 11.8, 11.4, 11.5 s | 11.5 s |

About 2%, which is inside the run-to-run spread. The first top-app sample is
cold-cache, not a core effect.

The flatness is the runtime's doing: **LiteRT-LM asks for four CPU threads on
both sides of the model.** Vision pins it outright
(`runtime/executor/vision_litert_compiled_model_executor.cc:91`,
`SetCpuOptions(cpu_options, 4)`) and the text executor takes it from
`CpuConfig.number_of_threads`, which `LlmExecutorSettings::CreateDefault` sets to
4 for the CPU backend (`runtime/executor/llm_executor_settings.cc:221`, default
also 4 at `llm_executor_settings.h:137`). Four threads on a 4+4+1 phone have
nothing to hand a ninth core.

**So 2% is a fact about this runtime, not about this phone**, and it should not
be carried to other on-device work here. A neighbouring lane measured the same
top-app/foreground pair on the same device with a stack that does not pin
threads, and saw between no change and 2.07x depending on input size: with the
process averaging 1.64 cores, a small model leans on the fastest core's clock
while a large one spreads out and stops noticing. Their measurement, not ours,
cited for the ratio and the mechanism only — their absolute per-model figures
are deliberately not reproduced here, and none of this belongs in anything
outbound (the cross-runtime publishing rule in HANDOFF.md covers it).

Worth keeping the check in mind rather than the number: screen off, lock screen,
or a pulled-down notification shade drop a process to `background`, and that one
is the 4-little-cores floor. The one-line test is the `cgroup` read above —
anything other than `/top-app` or `/foreground` and the timing is not the
device's.

## An invented verb silently dropped the text (2026-08-15)

The planner has five verbs. The model regularly answers with a sixth:

```json
{"action": "search", "target": "the search box", "text": "wifi"}
```

`Planning.parse` fell back on "an unknown verb that names a target is a tap",
which read that as *press the search box* and **discarded `"wifi"`**. The run
then pressed its way around the screen it had meant to type into: five steps,
eight model calls, no text ever entered.

The fix is to let the shape of the object decide, not the verb: text present
means type, a bare target means press.

```kotlin
typed.isNotEmpty() -> Act.Type(typed, target.ifEmpty { null })
target.isNotEmpty() -> Act.Tap(target)
```

Same goal, same build otherwise, straight after the fix:

| | before | after |
|---|---|---|
| steps | 5 | 2 |
| model calls | 8 | 3 |
| wall clock | 2 min 40 s | 2 min 10 s |
| outcome | wandered, never typed | typed `wifi`, then `{"action": "done"}` |

The lesson generalises past this parser. A small model will answer outside the
vocabulary it was given, so the fallback is not an edge case — it is a regular
path, and it should read every field the model filled in rather than the one
that names the verb.

## Some screens forbid the agent's badge (2026-08-15)

The agent now floats a badge over whatever it is driving — a face that looks
around, narrows while the model thinks, and walks to the point it is about to
press. Over most apps it works. Over **Settings' home page it never appears**,
and the reason is policy, not a bug:

```
Window{... com.android.settings/...SettingsHomepageActivity}:  HIDE_NON_SYSTEM_OVERLAY_WINDOWS
Window{... com.edgeagent.lab}:  mIsForceHiddenNonSystemOverlayWindow=true
                                mDrawState=READY_TO_SHOW  Surface: shown=false
```

A window may declare `HIDE_NON_SYSTEM_OVERLAY_WINDOWS`, and while it is visible
every non-system overlay on the device is force-hidden. Settings' home page
declares it — sensibly, since that is the screen where accessibility is granted
and an overlay there is the classic tapjacking setup.

The symptom is confusing: the badge is added without error, `mViewVisibility` is
0 (visible), the view draws, and `dumpsys window` reports `READY_TO_SHOW`. Only
`mIsForceHiddenNonSystemOverlayWindow` names the cause. Over the calculator the
same build reports `shown=true` and the badge is there.

**Consequences.** A demo that starts on Settings home shows no badge until the
first navigation; start somewhere else. Any product built on this seam has to
treat the badge as advisory — it can vanish for reasons the app cannot see, and
`Settings.canDrawOverlays()` returning true says nothing about whether the badge
is actually on screen right now.

Two smaller things learned building it:

- **`FLAG_NOT_TOUCHABLE` costs opacity.** A non-touchable system window is
  clamped to alpha 0.80, so a dark badge over a dark app reads as a smear of the
  app's own text. The badge is a near-white chip with dark type for that reason,
  and it is the one light surface in the project. Dropping the flag is not an
  option: the agent dispatches its own taps and a badge that swallowed one would
  break the thing it illustrates.
- **The badge must not be in the frame the model sees.** MediaProjection
  captures the whole display. `AgentOverlay.duringCapture` takes it off screen
  for the capture and puts it back — measured at 0.2–0.9 s per step.

## The stopping rule cannot see a calculator (2026-08-15)

Trying to film the badge on something other than Settings, the agent was given
"press 7 then times then 8 then equals" on the calculator. It pressed 7 and
stopped:

```
1. tapped the keypad — ok
stopped: the screen did not change — stopping rather than repeating
```

The tap worked; the display did change from blank to `7`. But the guard shrinks
both frames to 32×64 and compares mean brightness, and a digit appearing in one
corner of a mostly-black screen does not move that mean past a threshold of 6.
The loop read a correct action as a dead one.

So the rule that makes the loop safe on navigation makes it blind on data entry.
Both are the same measurement — "did the screen respond" — and the answer
depends entirely on how much of the screen a response is expected to occupy.
Anything that types into a field or fills a cell needs either a lower threshold
(and then noise stops the loop instead) or a different test: compare a region
around the point that was pressed, not the whole frame.

Not fixed. Recorded because the failure looks like a broken tap and is not one.
