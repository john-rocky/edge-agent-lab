---
license: other
license_name: lfm-open-license-v1.0
license_link: LICENSE
base_model: LiquidAI/LFM2.5-VL-3B
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

# LFM2.5-VL-3B — LiteRT-LM

[LiquidAI/LFM2.5-VL-3B](https://huggingface.co/LiquidAI/LFM2.5-VL-3B) converted to the **LiteRT-LM** (`.litertlm`) format for on-device inference with Google's [LiteRT-LM](https://github.com/google-ai-edge/litert-lm) runtime.

**Text + image work end-to-end on the released `litert-lm` 0.16.0 pip runtime** — the bundle carries the vision encoder, the vision adapter and the LFM2 image-placeholder metadata, so `litert-lm run … --attachment photo.png` just works. To our knowledge this is the first LFM2.5-VL in LiteRT form.

## Known issue: positional answers are wrong on the released runtime

On `litert-lm` 0.16.0 — and on current `main` — only the **top quarter of the image** reaches the model. Captioning, colour questions and OCR of a large dominant subject still work. Anything positional — locate, count, enumerate, "which one is at the bottom" — comes back wrong, with no error and well-formed output.

The cause is a shrink-factor assumption in the runtime's vision path, reported upstream as [LiteRT-LM#3246](https://github.com/google-ai-edge/LiteRT-LM/issues/3246). It affects every LFM2.5-VL bundle, not just this one: the family performs its 2×2 pixel-unshuffle in the vision *adapter* rather than the encoder, and the runtime assumes the opposite.

Quick check — a 512×512 image with 16 numbered horizontal bands, asked to list every number from top to bottom:

```
expected: 1 … 16    actual: 1 1 2 2 3 3 4 4 1
```

A repaired build exists (the pooling moved into the exported encoder, which makes the runtime's forwarded rows the correct pooled tokens). We have not replaced the files here, because the upstream fix may make the change unnecessary or incompatible — open a discussion on this repo if you need it now.

LFM2.5-VL-3B pairs Liquid AI's **hybrid text backbone** (22 gated short-convolution blocks + 8 grouped-query attention layers, 128k vocab) with a **SigLIP2 vision tower** (27 layers, hidden 1152) and a pixel-unshuffle projector. On this runtime an image is processed at 512×512 into 256 soft tokens (single image per prompt; the runtime resizes for you) — but see the known issue above: on 0.16.0 those 256 tokens carry only the top quarter of the picture.

| File | Recipe | Size |
|---|---|---|
| `LFM2.5-VL-3B_int8.litertlm` | int8 dynamic (text linears + convs + embedding, vision tower) | 3.55 GB |
| `LFM2.5-VL-3B_int4.litertlm` | text int4 blockwise-32 OCTAV linears, int8 embedding + lm_head; vision tower int8 | 2.35 GB |

| | |
|---|---|
| **Context (KV cache)** | 4096 max |
| **Image input** | 1 per prompt, resized to 512×512 → 256 tokens; PNG/JPEG via `--attachment` . On 0.16.0 those tokens cover only the top quarter — see the known issue |
| **Backend** | **CPU**, and **GPU with litert-lm ≥ 0.16.0** (macOS verified by generation; Android OpenCL expected per the LFM2.5 family — device numbers below as measured; iOS Metal fails at engine creation for this family, tracked upstream in [LiteRT-LM#3129](https://github.com/google-ai-edge/LiteRT-LM/issues/3129) — use CPU on iOS) |
| **Template** | bundled — ChatML-style; image placeholders are inserted by the runtime's LFM2 data processor (non-thinking model) |
| **Base model** | LiquidAI/LFM2.5-VL-3B (LFM Open License v1.0) |

## Quality

Sanity gates on the 0.16.0 pip CLI (greedy, fresh engine per question, `--cache no`). Vision: five deterministic synthetic fixtures (dominant color, large-text OCR, shape, counting three squares, largest word). Text: the 8-question gate used across our LiteRT conversions.

| Configuration | text 8Q | image 5Q |
|---|---|---|
| PyTorch bf16 (reference) | 7/8 | 5/5 |
| **LiteRT int8, CPU** | 7/8 | **5/5** |
| **LiteRT int8, GPU (macOS)** | 7/8 | **5/5** |
| **LiteRT int4-b32, CPU** | 7/8 | **5/5** |
| **LiteRT int4-b32, GPU (macOS)** | 7/8 | **5/5** |

All five image answers from both LiteRT variants are **verbatim identical to the bf16 reference** on both backends ("Red." / "Hello." / "Circle." / "Three." / "CAT."). The single text miss (rhyme completion answered "Purple.") is shared with the source model's behavior at greedy decoding, not a conversion artifact. Zero degenerate outputs across all runs.

**What the image gate does not show.** All five vision fixtures place their subject in the middle of the frame, below the cut described in the known issue above. They therefore cannot separate "the model resolved the image" from "the model answered from priors" — a bundle that sees only the top quarter still scores 5/5 on them. The band ruler above is the check that does separate the two. Concretely: `circle.png` puts its circle at y 128–384 of 512, entirely below the cut, and the 3B still answers "Circle." The 450M answers "Square." on the same fixture and flips to "Circle." once the bundle is repaired, with nothing else changed.

## Usage

```bash
pip install litert-lm
litert-lm run ./LFM2.5-VL-3B_int4.litertlm --prompt "Describe this image." --attachment photo.png
```

Text-only prompts work the same way without `--attachment`. `--vision-backend cpu|gpu` selects the vision encoder backend independently of the text backend.

## Speed

`litert-lm benchmark … --cache no`, litert-lm 0.16.0 pip, Apple M4 Max (128 GB), text path (prefill/decode; image encoding is a separate one-shot vision-encoder call at prompt time):

CPU backend:

| Variant | Prefill (256) | Prefill (1024) | Decode | TTFT |
|---|---|---|---|---|
| int8 | 156 tok/s | 387 tok/s | 36.0 tok/s | 1.67 s |
| int4 | 141 tok/s | 181 tok/s | 40.1 tok/s | 1.84 s |

GPU backend (`--backend gpu`; both variants verified to generate correct text and answer the image gate on GPU before quoting):

| Variant | Prefill (256) | Decode | TTFT |
|---|---|---|---|
| int8 | 1835 tok/s | 114.5 tok/s | 0.15 s |
| int4 | 1944 tok/s | 143.2 tok/s | 0.14 s |

On Android the same bundle runs GPU-accelerated. Pixel 8a (Tensor G3), `litert_lm_main` built from the v0.16.0 release tag, 292-token prompt, decode run to EOS (≈1.1k tokens sustained), `--disable_cache` (worst-case load; default caching makes subsequent loads much faster), int4 file:

| Backend | Prefill (292 tok) | Decode | TTFT |
|---|---|---|---|
| GPU (OpenCL) | 91.6 tok/s | 10.8 tok/s | 3.3 s |
| CPU | 14.1 tok/s | 5.8 tok/s | 20.9 s |

The text graph delegates fully on Android OpenCL (937/937 nodes, zero rejected ops). One operational note: the GPU path writes multi-GB compile caches next to the model by default — on a nearly-full device the cache write can fail mid-initialization; run with `--disable_cache` or free storage first.

## Conversion

Converted with the open pipeline in [hf-to-litertlm](https://github.com/john-rocky/hf-to-litertlm) (`lfm_work/convert_lfm25_vl.py`, litert-torch 0.9.3 `--task image_text_to_text`): the exact recipe, the int4 post-processing (OCTAV int4-b32 + int8 embedder + zero-scale repair + executor metadata, all vision sections preserved) and the text/image gate harnesses are in the repo's `REPRODUCE.md`.
