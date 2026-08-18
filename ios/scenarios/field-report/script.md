# Field report — demo script (draft, not yet recorded)

The business scenario: a photographed gauge becomes a note and tomorrow's
obligation, fully offline. The surprise is the date — "tomorrow at 9" is
an argument no on-device model can fill from thin air; watch whether it
asks the phone what today is first. Wordings are **not yet
device-verified**.

Tool set: `ToolBox.fieldReport`, 10 tools — read_text_in_latest_photo /
identify_latest_photo / photo_library_summary / write_note / read_notes /
create_reminder / list_reminders / create_calendar_event /
list_calendar_events / get_current_time.

| beat | say | expect |
|---|---|---|
| 1 | Read the text in my latest photo. | `read_text_in_latest_photo` — the gauge label, out loud on stage |
| 2 | Save that as a note. | `write_note` — the anaphora beat; the 1.2B is expected to fail it |
| 3 | Remind me tomorrow at 9 to file the report. | `create_reminder(due: tomorrow 09:00)` — possibly `get_current_time` first |
| 4 | What's still on my reminder list? | `list_reminders`, the new reminder reads back |

日本語版:

| beat | 言う | 期待 |
|---|---|---|
| 1 | さっき撮った写真の文字を読んで。 | `read_text_in_latest_photo` |
| 2 | それをメモに保存して。 | `write_note`(照応ビート — 1.2B はここで落ちる想定) |
| 3 | 明日の9時にレポートを出すのをリマインドして。 | `create_reminder`(先に `get_current_time` を呼ぶ個体も) |
| 4 | 残ってるリマインダーは? | `list_reminders` |

Design notes

- **The date is the test.** `create_reminder` wants ISO 8601. No model
  knows today's date from weights; the honest route is
  `get_current_time` → `create_reminder`. The bench scores the reminder
  call only (`dateResolvesTo: tomorrow`, resolved against the device's
  clock at run time) and treats a time lookup before it as a reasonable
  extra, same as Apple FM's location grounding in the coffee run.
- Beat 2 is the measured anaphora floor, on purpose. If the recorded cut
  needs it to work on the 1.2B, the recipe fix is a tool that reads the
  last result itself (the `speak_out_loud` pattern), not better wording.
- read vs identify is this pack's crop/resize: two photo tools one
  preposition apart.

Recording notes

- Launch with `--scenario report`.
- The latest photo must be the prop: a gauge, a meter, a label — retake
  it right before the take (beat 7 of another pack may have saved an
  edited copy as newest; delete strays in Photos first).
- Reminders and calendar prompt for permission on first use — grant
  before recording.
- Beat 3 creates a real reminder: delete it between takes or beat 4
  reads back a growing pile.
- Focus mode on, phone cooled, same as every pack.
