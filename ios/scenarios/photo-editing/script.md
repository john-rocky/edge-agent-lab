# Photo editing — demo script

Recorded 2026-08-18 on LFM2.5-1.2B-Instruct_int4 (take log
run-1787033283, 7/7 tool calls clean, ~55 s). The point on screen:
steering a parameter space with vague words, edits stacking on a photo
that never leaves the stage, a whole chain talked back out of existence,
and the person lifted clean off the background. No sliders appear at any
point.

| beat | say | expect |
|---|---|---|
| 1 | Make the photo a bit brighter. | `adjust_photo_brightness`, small positive amount |
| 2 | A bit warmer, too. | `adjust_photo_warmth` on top of beat 1 |
| 3 | Crop it square. | `crop_photo(square)`, still bright and warm |
| 4 | Undo everything — back to the original. | `revert_to_original`, the untouched photo returns |
| 5 | Give it a sepia look. | `apply_photo_filter(sepia)` |
| 6 | Remove the background. | `remove_background`, subject floats on the stage's black |
| 7 | Save it. | `save_edited_photo`, copy lands in the library |

日本語版:

| beat | 言う | 期待 |
|---|---|---|
| 1 | 写真をもう少し明るくして。 | `adjust_photo_brightness` 小さめの正値 |
| 2 | もう少し暖かい感じに。 | `adjust_photo_warmth` がビート1に重なる |
| 3 | 正方形に切り抜いて。 | `crop_photo(square)` |
| 4 | 全部やめて、元の写真に戻して。 | `revert_to_original` で無編集に戻る |
| 5 | セピアっぽくして。 | `apply_photo_filter(sepia)` |
| 6 | 背景を消して。 | `remove_background` で人物が黒背景に浮かぶ |
| 7 | 保存して。 | `save_edited_photo` |

Wording that failed on the way here (1.2B, all device-verified):

- "Undo everything" / "Revert to the original photo." → `undo_photo_edit`
  while the one-step undo was in the set; the stage cut
  (`ToolBox.photoStage`) drops it and the revert then routes.
- "Reset it — back to the original." → `resize_photo` (`res-` prefix).
- "Cut out the person." → `flip_photo`, even with `person` in the tool
  name `cut_out_person`. Renamed `remove_background`, beat says exactly
  that — routes cleanly.

Recording notes

- The photo needs a person or clear subject (beat 6), daylight, some
  color — warmth and sepia must read on camera.
- Each take's beat 7 saves an edited copy, which becomes the newest
  photo: **delete it in Photos before the next take** or the run starts
  from the previous take's output.
- Cool the phone between takes; prefill drops visibly when warm.
- Focus mode on — a notification costs the take.
