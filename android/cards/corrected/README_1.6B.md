---
license: other
license_name: lfm-open-license-v1.0
license_link: LICENSE
base_model: LiquidAI/LFM2.5-VL-1.6B
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

# LFM2.5-VL-1.6B — LiteRT-LM

[LiquidAI/LFM2.5-VL-1.6B](https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B) converted to the **LiteRT-LM** (`.litertlm`) format for on-device inference with Google's [LiteRT-LM](https://github.com/google-ai-edge/litert-lm) runtime — the middle of the family, between [LFM2.5-VL-450M](https://huggingface.co/litert-community/LFM2.5-VL-450M) and [LFM2.5-VL-3B](https://huggingface.co/litert-community/LFM2.5-VL-3B).

**Text + image work end-to-end on the released `litert-lm` 0.16.0 pip runtime**: the bundle carries the vision encoder, the vision adapter and the LFM2 image-placeholder metadata, so `litert-lm run … --attachment photo.png` just works.

## Known issue: positional answers are wrong on the released runtime

On `litert-lm` 0.16.0 — and on current `main` — only the **top quarter of the image** reaches the model. Captioning, colour questions and OCR of a large dominant subject still work. Anything positional — locate, count, enumerate, "which one is at the bottom" — comes back wrong, with no error and well-formed output.

The cause is a shrink-factor assumption in the runtime's vision path, reported upstream as [LiteRT-LM#3246](https://github.com/google-ai-edge/LiteRT-LM/issues/3246). It affects every LFM2.5-VL bundle, not just this one: the family performs its 2×2 pixel-unshuffle in the vision *adapter* rather than the encoder, and the runtime assumes the opposite.

Quick check — a 512×512 image with 16 numbered horizontal bands, asked to list every number from top to bottom:

```
expected: 1 … 16    actual: a runaway count that never stops at 16
```

The 1.6B degenerates rather than cutting off cleanly; the repaired build returns `1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16`.

A repaired build exists (the pooling moved into the exported encoder, which makes the runtime's forwarded rows the correct pooled tokens). We have not replaced the files here, because the upstream fix may make the change unnecessary or incompatible — open a discussion on this repo if you need it now.

LFM2.5-VL-1.6B pairs the hybrid LFM2 text backbone (16 layers: gated short-convolutions + grouped-query attention, hidden 2048, 64k vocab) with the **same large SigLIP2 vision tower as the 3B** (27 layers, hidden 1152). An image is processed at 512×512 into 256 soft tokens (single image per prompt; the runtime resizes for you) — but see the known issue above: on 0.16.0 those 256 tokens carry only the top quarter of the picture.

| File | Recipe | Size |
|---|---|---|
| `LFM2.5-VL-1.6B_int8.litertlm` | int8 dynamic (text linears + convs + embedding, vision tower) | 1.81 GB |
| `LFM2.5-VL-1.6B_int4.litertlm` | text int4 blockwise-32 OCTAV linears, int8 embedding + lm_head; vision tower int8 | **1.30 GB** |

| | |
|---|---|
| **Context (KV cache)** | 4096 max |
| **Image input** | 1 per prompt, resized to 512×512 → 256 tokens; PNG/JPEG via `--attachment` . On 0.16.0 those tokens cover only the top quarter — see the known issue |
| **Backend** | **CPU**, and **GPU with litert-lm ≥ 0.16.0** (macOS and Android OpenCL measured below; iOS Metal fails at engine creation for this family, tracked upstream in [LiteRT-LM#3129](https://github.com/google-ai-edge/LiteRT-LM/issues/3129) — use CPU on iOS) |
| **Template** | bundled — ChatML-style; image placeholders are inserted by the runtime's LFM2 data processor (non-thinking model) |
| **Base model** | LiquidAI/LFM2.5-VL-1.6B (LFM Open License v1.0) |

## Quality

Sanity gates on the 0.16.0 pip CLI (greedy, fresh engine per question, `--cache no`). Vision: five deterministic synthetic fixtures (dominant color, large-text OCR, shape, counting three squares, largest word). Text: the 8-question gate used across our LiteRT conversions.

| Configuration | text 8Q | image 5Q |
|---|---|---|
| PyTorch bf16 (reference) | — | 5/5 |
| **LiteRT int4-b32 (cpu & gpu)** | **8/8** | 3/5 |
| **LiteRT int8 (cpu & gpu)** | **8/8** | 3/5 |

Text is perfect across every configuration and backend. On the image side, color, large-text OCR and largest-word are answered correctly, and additional geometry probes (which corner an object is in, horizontal-vs-vertical stripes) also come back correct — but the fine-grained shape and counting fixtures miss on-device across all quantization levels *including an unquantized probe build*, while the PyTorch reference gets them right. We verified the conversion itself is exact (the exported vision tower and projector match PyTorch at cosine 1.0000 on identical inputs, and the prompt/token stream matches the HF processor token-for-token), so this is a runtime effect, not conversion loss. **Correction (2026-08-14):** we have since identified it — it is the defect described in the known issue above, and the shape and counting fixtures sit below the visible quarter. The 3B scores 5/5 on these fixtures despite being affected identically, because a larger model answers them from global context rather than from the pixels. Do not read the 3B's 5/5 as evidence that it sees more of the image.

## Usage

```bash
pip install litert-lm
litert-lm run ./LFM2.5-VL-1.6B_int4.litertlm --prompt "What does the text in this image say?" --attachment photo.png
```

Text-only prompts work the same way without `--attachment`. `--vision-backend cpu|gpu` selects the vision encoder backend independently of the text backend.

## Speed

`litert-lm benchmark … --cache no`, litert-lm 0.16.0 pip, Apple M4 Max (128 GB), text path (image encoding is a separate one-shot vision-encoder call at prompt time):

CPU backend:

| Variant | Prefill (256) | Prefill (1024) | Decode | TTFT |
|---|---|---|---|---|
| int8 | 365 tok/s | 796 tok/s | 70.5 tok/s | 0.72 s |
| int4 | 329 tok/s | 405 tok/s | 78.2 tok/s | 0.79 s |

GPU backend (`--backend gpu`; both variants verified to generate on GPU before quoting):

| Variant | Prefill (256) | Decode | TTFT |
|---|---|---|---|
| int8 | 3601 tok/s | 221.5 tok/s | 0.08 s |
| int4 | 3792 tok/s | 275.3 tok/s | 0.07 s |

On Android the same bundles run GPU-accelerated. Pixel 8a (Tensor G3), `litert_lm_main` built from the v0.16.0 release tag, 296-token prompt, decode run to EOS (1.5k–3.8k tokens sustained), `--disable_cache`:

| Variant | Backend | Prefill (296 tok) | Decode | TTFT |
|---|---|---|---|---|
| int4 | GPU (OpenCL) | 201 tok/s | 22.1 tok/s | 1.5 s |
| int4 | CPU | 37 tok/s | 13.6 tok/s | 8.1 s |
| int8 | GPU (OpenCL) | 403 tok/s | 15.9 tok/s | 0.80 s |
| int8 | CPU | 60 tok/s | 8.4 tok/s | 5.0 s |

The text graph delegates fully on Android OpenCL (543/543 nodes, zero rejected ops). As with the 450M, int4 prefills slower than int8 on CPU (blockwise-int4 repacking) but decodes markedly faster — pick by whether your prompts or your outputs dominate.

## Conversion

Converted with the open pipeline in [hf-to-litertlm](https://github.com/john-rocky/hf-to-litertlm) (`lfm_work/convert_lfm25_vl.py`, litert-torch 0.9.3 `--task image_text_to_text`): the exact recipe, the int4 post-processing (OCTAV int4-b32 + int8 embedder + zero-scale repair + executor metadata, all vision sections preserved) and the text/image gate harnesses are in the repo's `REPRODUCE.md`.
