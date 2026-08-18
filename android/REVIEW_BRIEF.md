# Review brief — re-audit of the 2026-08-14 findings

For a cold session re-examining this work. Written to be attacked, not
believed. Read [FINDINGS.md](FINDINGS.md) for the full detail; this file says
what is solid, what is inference, and what I got wrong on the way.

## Track record of the session that produced this

I published three different diagnoses of the same symptom. The first two were
wrong:

1. "Android collapses y while x stays right" — wrong. One target, one screen.
2. "Android points at the wrong element" — wrong. Same data, better story.
3. "The app sent the text content part before the image" — right, and isolated
   on-device with a single variable.

Both wrong calls came from generalising off one target on one screenshot. Weigh
the rest of this document accordingly, and note the rule that came out of it:
**no spatial claim on fewer than two targets and two images.**

## The two claims

### Claim 1 — LiteRT-LM truncates the image to its top quarter for LFM2.5-VL

**Confidence: high.** Source-read, artifact-read, measured on two runtimes, two
model sizes, and reproduced by a deterministic fixture.

The arithmetic (`vision_executor_utils.cc` → `vision_litert_compiled_model_executor.cc`)
writes `1024/4 = 256` of the encoder's 1024 output rows into the adapter's
1024-row input after `Clear()`. Verified present in `v0.16.0` (924e79c9) and in
the local `main` clone (c2ab9ab8), both read from the **source** trees — and on
**upstream HEAD `30391d9ba84b` (2026-08-14)**, fetched through the GitHub API
rather than the 5-week-old clone: derivation at `vision_executor_utils.cc:92-101`,
`num_patches` at `vision_litert_compiled_model_executor.cc:610-614`, truncating
write at `:648-650`. No existing upstream issue found.

Trap: `~/code/litert-lm/cmake/build/.../generated/src/...` is a stale copy that
differs from `main`'s source. I nearly reported a false difference from it. Read
`runtime/executor/*.cc`, never the generated tree.

How to falsify it in ~2 minutes:

```bash
CLI=~/code/litertlm-convert/.venv-lt016/bin/litert-lm
$CLI run ~/code/litertlm-chat-android/models/LFM2.5-VL-3B_int4.litertlm \
  --backend cpu --cache no --attachment fixtures/rows16.png \
  --prompt "The image is divided into horizontal bands, each printed with a number. List every number you can see, from top to bottom. Do not guess numbers you cannot see."
# 3B stock     -> "1 1 2 2 3 3 4 4 1"      (bands 1-4 only)
# 3B repaired  -> "1 1 1 2 2 3 3 ... 16 16"  (all 16)
# 450M stock   -> "1 2 3 4 4 4 1 2 ..."     450M repaired -> "1 2 3 ... 16"
```

**Independent of Claim 2.** Every desktop control used the CLI, which puts the
attachment before the text — so the 2/10 → 10/10 improvement from the repair was
measured with image-first throughout. Content order cannot explain it.

### Claim 2 — the Android grounding failure was our content order, not the runtime

**Confidence: high for the causal link, incomplete for the mechanism.**

Isolated on-device with `litert_lm_main` built for Android and given an image
flag. Same binary, bundle, image, prompt; only `--image_first` changes:

| target | truth | image-first | text-first |
|---|---|---|---|
| search bar | ~98 | `[500, 94]` | `[]` |
| Notifications | ~559 | `[500, 551]` | `[]` |
| Sound & vibration | ~642 | `[362, 629]` | `[]` |
| Storage | ~980 | `[500, 980]` | `[500, 981]` |

Re-run:

```bash
adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=/data/local/tmp ./litert_lm_main \
  --model_path=m3b.litertlm --backend=cpu --vision_backend=cpu \
  --image_path=probe.png --image_first=true --input_prompt_file=prompt.txt"
```

Provenance note: the Storage target is **not** in `fixtures/settings_pixel8a.json`
(that file has 10 other targets). Its ~980 truth comes from the row's own extent
in `probe.png`, which occupies normalised y≈955–1000 — verified by cropping that
band. Worth having to hand if a maintainer asks.

**Unexplained:** the Storage row resolves in both orders. If text-first simply
destroyed the image↔instruction binding, it should fail there too. Worth
attacking — it is the loose thread in this claim.

The order we used came from the LiteRT-LM skill doc
(`agents/skills/create-litert-lm-android-demo-app/references/inference_implementation.md`),
which says text MUST come before media. The vendor's own model card and
`litert-lm run --attachment` both put the image first.

## Not verified — do not repeat these as established

- **The preprocessed tensor was never inspected.** Preprocessing was cleared by
  behaviour (the device enumerates all 10 Settings rows correctly at a size
  where the runtime performs no resize) and by the AAR shipping the same
  `stb_image_preprocessor`. That is inference, not observation. An instrumented
  build could now dump it — the Android build works.
- **Fix A (the runtime-side fix) is built and measured** (2026-08-15): stock 450M reads `1…16`, stock 3B grounds `Notifications [500,551]`. Patch and matrix in FINDINGS.md. Not tested against a ViT-family bundle — none is on this machine.
- **"Grounding is a 3B-only capability"** rests on the 450M and 1.6B emitting
  round numbers across ~10 prompts. Plausible, lightly tested.
- **Storage x disagrees between runtimes** (`158` desktop vs `558` device) while
  y matches. Both land inside a full-width row so both scored as hits; the
  divergence is unexplained.
- **The GPU backend kills the 3B process** on this 8 GB device. Observed, not
  root-caused.
- **The repaired 1.6B bundle no longer exists** on disk or on the device, so the
  AAR ruler result recorded for it is not re-runnable as written. A ~90 s
  re-export restores it. The defect itself is now proven on the Android runtime
  directly (stock 3B through `litert_lm_main`), which does not depend on it.

## Environment as left

Device: Pixel 8a, `4C131JEKB15210`, ~15 GB free.

- `/data/local/tmp/litert_lm_main` — Android build with `--image_path` /
  `--image_first` (patch: `tools/litert_lm_main_image.patch`). Needs the `.so`
  files already beside it and `LD_LIBRARY_PATH=/data/local/tmp`.
- `/data/local/tmp/m3b.litertlm` — repaired 3B with `prefer_activation_type=fp32`.
- `/data/local/tmp/probe.png` — 320×768 Settings screenshot, the exact bytes the
  app fed the engine. `prompt.txt` / `p2..p4.txt` are the four grounding prompts.
- **`/data/local/tmp` also holds another lane's `.pte` files.** I cleared 29 GB
  of old test artifacts there earlier with the user's approval; new ones have
  appeared since. Do not sweep it blindly.
- App `com.edgeagent.lab` installed; bundle in its external files dir.
- Repaired bundles: `~/code/litertlm-convert/lfm25vl_work/out_fixb/`.
  Stock originals: `~/code/litertlm-chat-android/models/`.

**Android build recipe** (this was itself a blocker worth knowing):

```bash
cd ~/code/litert-lm-0160-android
bazelisk build //runtime/engine:litert_lm_main \
  --config=android_arm64 --enable_platform_specific_config
```

The repo's `build:android` sets `--noenable_platform_specific_config`, which
stops `build:macos` applying to the host. Every Rust crate with a derive macro
then fails as `error[E0463]: can't find crate for 'thiserror_impl'` even though
`--extern` is passed and the dylib on disk is a valid arm64 proc-macro (it has
`__rustc_proc_macro_decls_*`). Re-enabling the flag fixes it.

On one run the loader reported `dlopen: ... mis-aligned LINKEDIT string pool`,
which would explain it — but **I have not been able to reproduce that message on
demand** (forced proc-macro rebuilds since then yield only E0463). Treat the
dylib-corruption mechanism as a hypothesis; the symptom and the one-flag fix are
the reproducible parts. Log: `out/reaudit-2026-08-14/android_build_break.log`.

## Independent re-audit (2026-08-14, separate session)

A second session re-ran the lot hostilely. Both claims survived with
**digit-identical agreement** on all eight on-device A/B cells and on the ruler
strings. It also added a leg I had not run: the **stock** 3B pushed to the device
and driven through `litert_lm_main` returns `1 1 2 2 3 3 4 4 1` — the same cut as
the Mac, on the Android runtime, with no AAR involved. So Claim 1 no longer
depends on the AAR path at all.

Raw logs and the exact commands: `out/reaudit-2026-08-14/`.

Its five corrections are folded in above (ruler string for the 3B, the LINKEDIT
downgrade, upstream HEAD, the missing draft files, the vanished 1.6B bundle).
Nothing material was overturned.

## Suggested order of attack

1. Re-run the `rows16` ruler on stock vs repaired. If that does not reproduce,
   Claim 1 is wrong and everything downstream is suspect.
2. Re-run the `--image_first` A/B on device. Then explain the Storage row.
3. Dump the preprocessed tensor with an instrumented build and diff against the
   desktop run on `probe.png`. This is the one claim resting purely on inference.
4. The upstream reports are **filed** (2026-08-14, as john-rocky), bodies kept
   in `upstream/`:
   - [#3246](https://github.com/google-ai-edge/LiteRT-LM/issues/3246) — vision truncation
   - [#3247](https://github.com/google-ai-edge/LiteRT-LM/issues/3247) — Android build break
   - [#3248](https://github.com/google-ai-edge/LiteRT-LM/issues/3248) — content-order docs + CLI image input

   If any claim above turns out wrong, correct it in-thread rather than
   silently — they are public.
