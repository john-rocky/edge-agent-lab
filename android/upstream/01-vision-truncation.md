# Draft 1 — vision adapter truncation (LFM2.5-VL sees only the top quarter)

Target: `google-ai-edge/LiteRT-LM` issue. **Filed: [#3246](https://github.com/google-ai-edge/LiteRT-LM/issues/3246)** (2026-08-14, as john-rocky).
Verified against upstream HEAD `30391d9ba84b` (2026-08-14).

---

Thanks for 0.16.0 — the hybrid VLM path has been solid for us, and image input
through the Android AAR worked first try.

Flagging something that affects any LFM2.5-VL bundle today: only the top quarter
of an image reaches the model, with no error and plausible-looking output.

**What happens.** `vision_executor_utils.cc:92-101` derives

```
num_tokens_per_image    = adapter output dim[-2]        = 256
patch_num_shrink_factor = encoder input dim[-2] / that  = 1024 / 256 = 4
```

and `vision_litert_compiled_model_executor.cc:610-614, 648-650` then writes only
256 of the encoder's 1024 output rows into the adapter's 1024-row input, after
`Clear()`:

```cpp
num_patches = (num_patches_from_input + patch_num_shrink_factor - 1) /
              patch_num_shrink_factor;
...
adapter_input_buffers[0].Clear();
adapter_input_buffers[0].Write<float>(absl::MakeSpan(
    encoder_output_data.data(), num_patches * encoder_output_dim));
```

The other 768 rows stay zero. In patch-raster order the surviving 256 are the top
8 of 32 patch rows.

The derivation assumes the encoder performs the spatial shrink. LFM2.5-VL does it
in the adapter — `multi_modal_projector` applies the 2×2 pixel-unshuffle — so the
encoder emits all 1024 rows. The comment just above at `:89-91` names LFM2 VL as
the single-input case this path covers, so I read this as an unnoticed assumption
rather than an unsupported model.

**How it shows up.** A 512×512 image with 16 numbered horizontal bands, asked to
list every number top to bottom:

| bundle | reply |
|---|---|
| LFM2.5-VL-3B int4, stock | `1 1 2 2 3 3 4 4 1` |
| LFM2.5-VL-450M int4, stock | `1 2 3 4 4 4 1 2 3 3 1 2 2 1 1 2 2 1 1` |
| LFM2.5-VL-450M int4, repaired | `1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16` |
| LFM2.5-VL-3B int4, repaired | all 16, each number repeated (`1, 1, 1, 2, 2, … 16, 16`) |

Bands 1–4 of 16 before the repair, all 16 after, both model sizes. (The
fixture prints each number at three x-positions per band, which is why the 3B
lists repeats.) A vertical ruler is unaffected — `cols8`
returns `1 2 3 4 5 6 7 8` — so the loss is exactly the raster prefix the
arithmetic predicts. Same cut on the desktop pip CLI and on-device through
`litert_lm_main` built for Android.

On a 1080×2400 screenshot with 10 grounding targets, HF transformers scores 10/10
and the runtime 2/10; the two hits are the only targets above y=250/1000.

**Why I'm flagging it now:** the `litert-community/LFM2.5-VL-{450M,1.6B,3B}`
bundles we published are affected, so anyone pulling them today gets silently
wrong spatial answers. We've repaired them from the conversion side — moving the
pixel-unshuffle into the exported encoder makes the 256 forwarded rows exactly
the pooled tokens the adapter expects, verified 2/10 → 10/10 with no runtime
change. The runtime side is yours to judge.

Happy to send the ruler fixture generator or the converter-side diff in whatever
form is easiest to use.
