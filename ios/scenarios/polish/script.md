# Polish — hand it a photo and say nothing

The demo. The photo goes in with no words at all; the model looks and
makes it look its best — judging what *this* picture needs and applying
the edits one after another, gently. Then three words each. Apple's model,
natively (`Attachment` in, `ImageReference` out); `--voice` for the
spoken beats. Launch:
`--autorun --backend apple --scenario polish [--voice]`.

| beat | say | expect |
|---|---|---|
| 1 | *(nothing — the photo alone)* | a chain of gentle edits chosen from the pixels: exposure / brightness / warmth / contrast / color / straightening, then one sentence on what changed and why |
| 2 | A little more. | the same direction, one more step |
| 3 | Now cut her out from the background. | remove_background |
| 4 | Save it. | save_edited_photo |

日本語版: (無言) → 「もう少し。」→ 「彼女を背景から切り抜いて。」→ 「保存して。」

Design

- **The silent contract lives in the instructions**: "a photo sent with
  no words means: make it look its best — judge what this picture needs
  … apply those edits one after another, gently, then say in one sentence
  what you changed and why." The chat honours the same contract: attach a
  photo, send with the field empty.
- **Steps, not numbers.** The vision tools take `direction` (brighter /
  darker, warmer / cooler, more / less…) and `strength` (a_little / some
  / a_lot → 15 / 35 / 60 %, or 0.3 / 0.7 / 1.2 stops). Asked for 0–100
  the model answered 100 every time — the recipe "vague amounts land on
  the rail", applied. "A little more" is a_little in the same direction.
- **The model is shown its own work**: every beat attaches the photo as it
  is now, so "a little more" is judged on the already-edited picture.

Not yet run — the phone was in use. Recording notes: pick a photo that
*needs* something (a touch dark, a little cool) so the silent beat has
work to do; a person in it makes beat 3 land; beat 4 saves a copy —
delete it before the next take.
