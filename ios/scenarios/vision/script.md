# Vision — the pixels pick the tool

Foundation Models' vision, the native way. The photo goes into the
prompt with every beat as a labelled `Attachment` (Apple's model reads it
itself; a LiteRT LFM2.5-VL bundle through the adapter), and every photo
tool takes an `ImageReference` — the model looks, decides, and names the
picture it means; the tool resolves the label against the live transcript
(`Tools/VisionTools.swift`). No beat names a tool or an adjustment. The
conditional beats are routing decided by pixels — the right answer may
be no call at all. Tools: `ToolBox.vision`, 14. Launch:
`--autorun --backend apple --scenario vision`; `--voice` for spoken
beats; `--scenario look` is the same photo with no tools, to check that
the model sees before reading anything into what it routes.

Recorded run, 2026-08-19 08:37, Apple FM, a portrait of an elderly woman
in a field with mountains behind (no text):

| beat | say | what happened |
|---|---|---|
| 1 | What's in this photo? | described it — scarf, walking stick, mountains, smiling — no call |
| 2 | If there's any text in it, save that text as a note. | read_text_in_photo → none → **no note written** |
| 3 | If there's a person in it, cut them out from the background. | remove_background — "focusing on the elderly woman" |
| 4 | Is there anything you'd fix about it? If so, do it. | auto_enhance_photo |
| 5 | Now make it look its best, and save it. | adjust_photo_brightness(+100, the rail again) → save_edited_photo — a chain |

日本語版(未実測):

| beat | 言う |
|---|---|
| 1 | この写真、何が写ってる? |
| 2 | 文字が写っていたら、その文字をメモに保存して。 |
| 3 | 人が写っていたら、背景から切り抜いて。 |
| 4 | 直したほうがいい所があれば直して。 |
| 5 | いちばん良く見えるようにして、保存して。 |

What it took to get here (all measured the same morning)

- **The model sees.** `capabilities` reports vision — and per the
  framework's own docs, a request needing a capability the model does
  not declare is thrown out by the system before the executor runs, so
  an attachment that goes through *is* being seen; with no tools it
  described the photo, said yes to a person, called the exposure right
  and the text absent. The first vision run looked blind — it removed
  the background of a mountain range because a beat said "if there's a
  person" — and the cause was our stock instructions ("prefer a tool
  over guessing, call it instead of answering"). The vision packs get
  their own instructions: look first; a conditional is answered by the
  pixels; call nothing when the condition is not met.
- **The label the model reaches for.** Attachments were labelled
  `photo`; the model wrote `image` in every `ImageReference` and nothing
  resolved. Attachments are now labelled `image` (Apple's docs use
  image-0, image-1), and a label that still resolves to nothing falls
  back to the newest image in the transcript — with one photo in play
  there is only one thing the model can mean.
- **Beat order is beat logic.** The model is shown its own work, so a
  makeover before the conditionals leaves them nothing to do (the first
  order rotated the already-cut-out portrait 180°). Conditionals first,
  makeover and save last.
- **What a 450M vision bundle does:** sees ("Mountains") and never
  routes — every beat answered in words. See-and-choose has to be split
  for a model that size (ask it for an enum, let the app call).

Recording notes: the newest library photo is the prop; a person plus
some text (a menu, a sign) makes beats 2 and 3 both fire. Beat 5 saves a
copy — delete it before the next take.
