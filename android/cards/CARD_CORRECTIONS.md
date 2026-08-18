# Card corrections — litert-community/LFM2.5-VL-{3B,1.6B,450M}

Drafted and **applied 2026-08-14**. Live on all three HF repos:
[3B](https://huggingface.co/litert-community/LFM2.5-VL-3B/commit/c25a47d49f79023507129a178b37ed6df04bbf0b) ·
[1.6B](https://huggingface.co/litert-community/LFM2.5-VL-1.6B/commit/cd287604da4b3300f576bc4de28f10ef56ea0f7a) ·
[450M](https://huggingface.co/litert-community/LFM2.5-VL-450M/commit/b563db3dce3dfdd08c2e1069b9daab24f49324c6).
Local copies in `~/code/litertlm-convert/lfm25vl_work/cards/` synced to match. The three published cards are byte-identical
to `~/code/litertlm-convert/lfm25vl_work/cards/README_*.md`, so each edit lands
in both places.

## Why these three edits and not a re-upload of the weights

The weights are a separate decision, and the argument for changing them is
weaker than the argument for changing the card:

- The defect is in the runtime ([#3246](https://github.com/google-ai-edge/LiteRT-LM/issues/3246)).
  If it is fixed the way that issue proposes — deriving the forwarded row count
  from the adapter's *input* shape — then stock and repaired bundles both work,
  and no re-upload was needed.
- A different upstream fix could break the repaired bundle. If the runtime
  instead assumes `shrink = 1` for single-input encoders, it would try to read
  1024 rows from our repaired encoder's 256-row output.
- Repaired bundles diverge from what stock `litert-torch` produces, so anyone
  re-converting from HF gets something different from what we published.

The card is different: **it carries a measured claim we can no longer stand
behind**, and that is ours alone to fix regardless of what upstream does.

---

## Edit 1 — add a known-issue block after the opening claim

Insert immediately after the "**Text + image work end-to-end…**" paragraph
(line 24), before the architecture paragraph.

> ## Known issue: positional answers are wrong on the released runtime
>
> On `litert-lm` 0.16.0 — and on current `main` — only the **top quarter of the
> image** reaches the model. Captioning, colour questions and OCR of a large
> dominant subject still work. Anything positional — locate, count, enumerate,
> "which one is at the bottom" — comes back wrong, with no error and
> well-formed output.
>
> The cause is a shrink-factor assumption in the runtime's vision path, reported
> upstream as [LiteRT-LM#3246](https://github.com/google-ai-edge/LiteRT-LM/issues/3246).
> It affects every LFM2.5-VL bundle, not just this one: the family performs its
> 2×2 pixel-unshuffle in the vision *adapter* rather than the encoder, and the
> runtime assumes the opposite.
>
> Quick check — a 512×512 image with 16 numbered horizontal bands, asked to list
> every number from top to bottom:
>
> ```
> MODEL_RULER_LINE
> ```
>
> A repaired build exists (the pooling moved into the exported encoder, which
> makes the runtime's forwarded rows the correct pooled tokens). We have not
> replaced the files here, because the upstream fix may make the change
> unnecessary or incompatible — open an issue on this repo if you need it now.

Per-model `MODEL_RULER_LINE`, measured, greedy, CPU, `--cache no`:

| card | line to use |
|---|---|
| 3B | `expected: 1 … 16    actual: 1 1 2 2 3 3 4 4 1` |
| 450M | `expected: 1 … 16    actual: 1 2 3 4 4 4 1 2 3 3 1 2 2 1 1 2 2 1 1` |
| 1.6B | `expected: 1 … 16    actual: a runaway count that never stops at 16` |

The 1.6B degenerates rather than cutting cleanly; the repaired build returns
`1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16`. Say that plainly rather than implying
the same clean cut as the other two.

## Edit 2 — qualify the soft-token sentence

Line 26 currently ends:

> On this runtime an image is processed at 512×512 into 256 soft tokens (single
> image per prompt; the runtime resizes for you).

Replace the parenthetical tail with:

> On this runtime an image is processed at 512×512 into 256 soft tokens (single
> image per prompt; the runtime resizes for you) — but see the known issue
> above: on 0.16.0 those 256 tokens carry only the top quarter of the picture.

The same qualifier belongs on the **Image input** row of the spec table
(line 36).

## Edit 3a (450M and 1.6B only) — replace the wrong cause

Both smaller cards already report their image misses (450M 4/5, 1.6B 3/5) and
explain them wrongly. Those explanations predate the root cause and must be
replaced, not merely annotated.

- **450M**, current text blames model size: *"At 450M scale some fine-grained
  visual answers sit close to decision boundaries on-device."* This is wrong.
  Repairing the bundle flips the shape answer from `Square.` to `Circle.` with
  nothing else changed.
- **1.6B**, current text says *"a runtime-interaction effect on precise
  contour/counting answers"* — right direction, no mechanism, and it sends
  readers to the 3B for "fine shape discrimination".
- Both cards recommend the 3B when finer visual reasoning is needed. **The 3B is
  affected identically**; it scores 5/5 on these fixtures because a larger model
  answers them from global context, not because it sees more of the picture.
  That recommendation has to go.

Replacement text is applied in `cards/corrected/README_450M.md` and
`README_1.6B.md`.

## Edit 3b (3B only) — say what the image gate does and does not show

The `5/5` numbers and the "verbatim identical to the bf16 reference" sentence are
both accurate as measured. Leave them. Add this after line 53:

> **What the image gate does not show.** All five vision fixtures place their
> subject in the middle of the frame, below the cut described above. They
> therefore cannot separate "the model resolved the image" from "the model
> answered from priors" — a bundle that sees only the top quarter still scores
> 5/5 on them. The band ruler in the known-issue section is the check that does
> separate the two, and any future gate here needs at least one target below the
> 25% line and one question whose answer depends on position.

Concretely: `circle.png` puts its circle at y 128–384 of 512, entirely below the
cut, and the 3B still answers "Circle." The 450M answers "Square." on the same
fixture and flips to "Circle." once the bundle is repaired, with nothing else
changed.

---

## Order of operations

1. Apply edits 1–3 to the three HF cards and to the local copies.
2. Leave the weights alone pending #3246.
3. If upstream fixes it as proposed, drop the known-issue block and restore the
   plain claim. If they fix it another way, re-test the repaired bundles against
   the new runtime before publishing them.
