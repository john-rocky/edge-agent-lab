# Vision — the pixels pick the tool

The photo goes into the prompt with every beat (iOS 27's `Attachment`,
read natively by Apple's model, or through the LiteRT adapter by an
LFM2.5-VL bundle), and what the model does depends on what it sees. No
beat names a tool or an adjustment: "fix it" on a dark photo should
become brightness, on a tilted one rotate, on a menu OCR. The
conditional beats are routing decided by pixels — the right answer may
be no call at all. Tools: `ToolBox.vision` (the 16 stage editing tools +
read text, identify, note), 19. Launch:
`--autorun --backend apple --scenario vision`, or `--model VL-450M`.
Add `--voice` and the beats are spoken.

| beat | say | expect |
|---|---|---|
| 1 | What's in this photo? | an answer from the picture, no call needed (or identify_latest_photo) |
| 2 | What would you fix about it? Go ahead and do it. | the edit the *photo* needs — brightness on a dark one, rotate on a tilted one, auto_enhance when it can't say |
| 3 | Now make it look its best. | another edit or auto_enhance, judged on the photo *as edited by beat 2* (the attachment is the current stage image) |
| 4 | If there's any text in it, save that text as a note. | read_text_in_latest_photo → write_note when there is text; nothing when there isn't |
| 5 | If there's a person in it, remove the background. | remove_background only if someone is in the frame |

Not yet run. Two open questions the first run answers: whether Apple's
system model accepts image attachments on iOS 27 beta 5 at all, and
whether a 450M vision bundle can both see and route (it may see and not
route — then the VL-3B, if it fits next to a 19-tool list, is the next
try). Beat 3's "as edited" is the design point: the model is shown its
own work.

Recording notes: pick the stage photo (newest in the library) to make
beats 4–5 decisive — a menu with a person in front of it hits both.
