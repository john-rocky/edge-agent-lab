---
license: other
license_name: lfm-open-license-v1.0
license_link: LICENSE
base_model: LiquidAI/LFM2.5-VL-450M
tags:
  - litert
  - litert-lm
  - litertlm
  - on-device
  - edge
  - vision
  - vlm
  - hybrid
  - liquid
pipeline_tag: image-text-to-text
library_name: litert-lm
---

# LFM2.5-VL-450M — LiteRT-LM

[LiquidAI/LFM2.5-VL-450M](https://huggingface.co/LiquidAI/LFM2.5-VL-450M) converted to the **LiteRT-LM** (`.litertlm`) format for on-device inference with Google's [LiteRT-LM](https://github.com/google-ai-edge/litert-lm) runtime — the small sibling of [litert-community/LFM2.5-VL-3B](https://huggingface.co/litert-community/LFM2.5-VL-3B), at a size that fits almost anywhere (int4 bundle: **0.41 GB**).

**Text + image work end-to-end on the released `litert-lm` 0.16.0 pip runtime**: the bundle carries the vision encoder, the vision adapter and the LFM2 image-placeholder metadata, so `litert-lm run … --attachment photo.png` just works.

## Known issue: positional answers are wrong on the released runtime

On `litert-lm` 0.16.0 — and on current `main` — only the **top quarter of the image** reaches the model. Captioning, colour questions and OCR of a large dominant subject still work. Anything positional — locate, count, enumerate, "which one is at the bottom" — comes back wrong, with no error and well-formed output.

The cause is a shrink-factor assumption in the runtime's vision path, reported upstream as [LiteRT-LM#3246](https://github.com/google-ai-edge/LiteRT-LM/issues/3246). It affects every LFM2.5-VL bundle, not just this one: the family performs its 2×2 pixel-unshuffle in the vision *adapter* rather than the encoder, and the runtime assumes the opposite.

Quick check — a 512×512 image with 16 numbered horizontal bands, asked to list every number from top to bottom:

```
expected: 1 … 16    actual: 1 2 3 4 4 4 1 2 3 3 1 2 2 1 1 2 2 1 1
```

A repaired build exists (the pooling moved into the exported encoder, which makes the runtime's forwarded rows the correct pooled tokens). We have not replaced the files here, because the upstream fix may make the change unnecessary or incompatible — open a discussion on this repo if you need it now.

LFM2.5-VL-450M pairs the hybrid LFM2 text backbone (16 layers: gated short-convolutions + grouped-query attention, 64k vocab) with a compact SigLIP2 vision tower (12 layers, hidden 768). An image is processed at 512×512 into 256 soft tokens (single image per prompt; the runtime resizes for you) — but see the known issue above: on 0.16.0 those 256 tokens carry only the top quarter of the picture.

| File | Recipe | Size |
|---|---|---|
| `LFM2.5-VL-450M_int8.litertlm` | int8 dynamic (text linears + convs + embedding, vision tower) | 0.56 GB |
| `LFM2.5-VL-450M_int4.litertlm` | text int4 blockwise-32 OCTAV linears, int8 embedding + lm_head; vision tower int8 | **0.41 GB** |

| | |
|---|---|
| **Context (KV cache)** | 4096 max |
| **Image input** | 1 per prompt, resized to 512×512 → 256 tokens; PNG/JPEG via `--attachment` . On 0.16.0 those tokens cover only the top quarter — see the known issue |
| **Backend** | **CPU**, and **GPU with litert-lm ≥ 0.16.0** (macOS/Android OpenCL per the LFM2.5 family; iOS Metal fails at engine creation for this family, tracked upstream in [LiteRT-LM#3129](https://github.com/google-ai-edge/LiteRT-LM/issues/3129) — use CPU on iOS) |
| **Template** | bundled — ChatML-style; image placeholders are inserted by the runtime's LFM2 data processor (non-thinking model) |
| **Base model** | LiquidAI/LFM2.5-VL-450M (LFM Open License v1.0) |

## Quality

Sanity gates on the 0.16.0 pip CLI (greedy, fresh engine per question, `--cache no`). Vision: five deterministic synthetic fixtures (dominant color, large-text OCR, shape, counting three squares, largest word). Text: the 8-question gate used across our LiteRT conversions.

| Configuration | text 8Q | image 5Q |
|---|---|---|
| PyTorch bf16 (reference) | — | 5/5 |
| **LiteRT int4-b32, CPU (recommended)** | **8/8** | **4/5** |
| LiteRT int8, CPU | 6/8 | 3/5 |

**int4 is the better variant of this model on our gates** — it answers the color, OCR, counting and largest-word fixtures correctly and misses only the shape question. **Correction (2026-08-14):** these misses are not a 450M-scale limitation. They are the runtime defect described in the known issue above — the shape and counting fixtures place their subject below the visible quarter. Repairing the bundle flips the shape answer from "Square." to "Circle." with nothing else changed, and the band ruler goes from `1 2 3 4 …` to a clean `1 … 16`. The conversion was always exact (the exported vision tower matches PyTorch at cosine 1.0000, and an unquantized bundle reproduces the same misses). Note that the 3B is affected identically; it scores 5/5 on these fixtures because a larger model answers them from global context, not because it sees more of the image.

## Usage

```bash
pip install litert-lm
litert-lm run ./LFM2.5-VL-450M_int4.litertlm --prompt "What does the text in this image say?" --attachment photo.png
```

Text-only prompts work the same way without `--attachment`. `--vision-backend cpu|gpu` selects the vision encoder backend independently of the text backend.

## Speed

`litert-lm benchmark … --cache no`, litert-lm 0.16.0 pip, Apple M4 Max (128 GB), text path (prefill/decode; image encoding is a separate one-shot vision-encoder call at prompt time):

CPU backend:

| Variant | Prefill (256) | Prefill (1024) | Decode | TTFT |
|---|---|---|---|---|
| int8 | 1088 tok/s | 2240 tok/s | 129.2 tok/s | 0.24 s |
| int4 | 1026 tok/s | 1196 tok/s | 127.0 tok/s | 0.26 s |

GPU backend (`--backend gpu`; both variants verified to generate on GPU before quoting — int4 also passes the image gate on GPU, 4/5):

| Variant | Prefill (256) | Decode | TTFT |
|---|---|---|---|
| int8 | 8443 tok/s | 360.0 tok/s | 0.03 s |
| int4 | 8296 tok/s | 354.2 tok/s | 0.03 s |

On Android the same bundles run GPU-accelerated. Pixel 8a (Tensor G3), `litert_lm_main` built from the v0.16.0 release tag, 296-token prompt, decode run to EOS (0.9k–3.8k tokens sustained), `--disable_cache`:

| Variant | Backend | Prefill (296 tok) | Decode | TTFT |
|---|---|---|---|---|
| int4 | GPU (OpenCL) | 528 tok/s | 33.1 tok/s | 0.59 s |
| int4 | CPU | 92 tok/s | 22.6 tok/s | 3.3 s |
| int8 | GPU (OpenCL) | 578 tok/s | 31.1 tok/s | 0.54 s |
| int8 | CPU | 177 tok/s | 15.8 tok/s | 1.7 s |

The text graph delegates fully on Android OpenCL (543/543 nodes, zero rejected ops). int4 prefills slower than int8 on CPU (blockwise-int4 repacking) but decodes ~40% faster — pick by whether your prompts or your outputs dominate.

## Conversion

Converted with the open pipeline in [hf-to-litertlm](https://github.com/john-rocky/hf-to-litertlm) (`lfm_work/convert_lfm25_vl.py`, litert-torch 0.9.3 `--task image_text_to_text`): the exact recipe, the int4 post-processing (OCTAV int4-b32 + int8 embedder + zero-scale repair + executor metadata, all vision sections preserved) and the text/image gate harnesses are in the repo's `REPRODUCE.md`.
