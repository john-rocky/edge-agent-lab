# Draft 3 — documented content order breaks grounding

Target: `google-ai-edge/LiteRT-LM` issue (docs), optionally with the
`litert_lm_main` image-input patch attached as a PR. **Filed: [#3248](https://github.com/google-ai-edge/LiteRT-LM/issues/3248)** (2026-08-14, as john-rocky).

---

Thanks for shipping the demo-app skill with the repo — we built our Android app
straight off it. The rule that `audioBackend` must be strictly CPU
(`compliance_checklist_inference.md:74-78`) and the Adreno crash guidance in
section 1 of `inference_implementation.md` both saved us real time.

One line in it costs grounding accuracy, and it took us a day to find because
nothing errors.

`agents/skills/create-litert-lm-android-demo-app/references/inference_implementation.md:92-94`:

> **Content Order Check**: You MUST add `Content.Text` to the contents list
> BEFORE any media content (like `Content.Image` or `Content.Audio`) to match
> model expectations.

With LFM2.5-VL that order describes the screen correctly and cannot locate
anything on it. Measured on-device with `litert_lm_main`, same binary, bundle,
image and prompt — only the order of the two content parts changes:

| target | ground truth | image first | text first |
|---|---|---|---|
| search bar | ~98 | `[500, 94]` | `[]` |
| Notifications | ~559 | `[500, 551]` | `[]` |
| Sound & vibration | ~642 | `[362, 629]` | `[]` |
| Storage | ~980 | `[500, 980]` | `[500, 981]` |

4 of 4 against 1 of 4. Text-first is not uniformly broken, which is what makes it
hard to spot — captioning and OCR still look fine, and one row still resolves.

Two things in the same ecosystem point the other way: `litert-lm run --help` says
"Attachements are placed before the first user text prompt", and the LFM2.5-VL
model card puts the image content part first in every example. I don't know
whether the documented order is right for other model families, so this may be a
per-family note rather than a straight correction.

**Related:** `litert_lm_main` has no image input, so Android image inference has
no reference CLI to diff an app against — that gap is why the above took a day.
I've added `--image_path` / `--image_first` locally (about 40 lines: the flags, a
vision backend when an image is present, and `SetVisionModalityEnabled(true)` so
the vision executor loads). Glad to open it as a PR in whatever shape suits, or
to leave it here if you'd rather build it differently.
