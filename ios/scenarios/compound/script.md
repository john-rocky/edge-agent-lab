# Compound — one sentence, one call, several things happen

The compound tools (`start_focus_session`, `morning_briefing`,
`copy_my_location`, `save_photo_text_as_note`) each walk several APIs
inside one call. The stage set carries the single tools too
(`ToolBox.compound + focus + briefing`, 21): the point on screen is the
model choosing the one call over the three. Launch:
`--autorun --backend apple --scenario compound`.

| beat | say | Apple FM, 2026-08-19 |
|---|---|---|
| 1 | I need to focus for 20 minutes. | start_focus_session(20) chosen ✓ — then AlarmKit refused the timer (fixed since: countdown face + notification fallback; re-check pending) |
| 2 | Give me my morning briefing. | morning_briefing ✓ — one call, five readings; the answer kept time, battery, steps and dropped calendar/reminders |
| 3 | Copy where I am so I can send it to someone. | copy_my_location ✓ — place, address, map link on the clipboard |
| 4 | Read my latest photo and keep the text as a note. | save_photo_text_as_note ✓ (photo had no text; said so, saved nothing) |

Design notes: `minutes`, optional, default 25 — every model asked for
seconds got the arithmetic wrong once and Apple FM asked "what for?" on
a required label (recipes). Compounds are built from the single tools'
`call` bodies so the two never drift.
