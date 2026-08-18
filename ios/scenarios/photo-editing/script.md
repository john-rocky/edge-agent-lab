# Photo editing — demo script

The point on screen: steering a parameter space with vague words, edits
stacking on edits, and a mistake talked back out of existence. No sliders
appear at any point.

| beat | say | expect |
|---|---|---|
| 1 | Make the photo a bit brighter. | `adjust_photo_brightness`, small positive amount |
| 2 | A bit warmer, too. | `adjust_photo_warmth` on top of beat 1 |
| 3 | Crop it square. | `crop_photo(square)`, still bright and warm |
| 4 | Too much — undo that. | `undo_photo_edit`, the crop comes back off |
| 5 | Give it a sepia look. | `apply_photo_filter(sepia)` |
| 6 | Save it. | `save_edited_photo`, copy lands in the library |

日本語版:

| beat | 言う | 期待 |
|---|---|---|
| 1 | 写真をもう少し明るくして。 | `adjust_photo_brightness` 小さめの正値 |
| 2 | もう少し暖かい感じに。 | `adjust_photo_warmth` がビート1に重なる |
| 3 | 正方形に切り抜いて。 | `crop_photo(square)`、明るさ・暖かさは維持 |
| 4 | やっぱりやりすぎ、戻して。 | `undo_photo_edit` でクロップが外れる |
| 5 | セピアっぽくして。 | `apply_photo_filter(sepia)` |
| 6 | 保存して。 | `save_edited_photo` でライブラリに保存 |

Recording notes

- The edit chain is the demo: each beat's result must visibly include the
  previous beats. A fresh-loaded photo mid-run means the chain broke.
- Beat 4 (undo by voice) is the surprise beat — leave a breath after it.
- Pick a photo where warmth and sepia read on camera: daylight, some sky.
- Cool the phone between takes; prefill drops visibly when warm.
