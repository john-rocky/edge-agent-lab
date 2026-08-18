# Focus — demo script (draft, not yet recorded)

Compound device control: one vague sentence steering notifications, a
timer and the screen itself. The finale is two tools out of one sentence
— the chaining beat the photo pack never had. Wordings below are written
against the measured recipes (call-order phrasing for the chain, "the
words the user will say" for names) but are **not yet device-verified**;
expect this table to change the way the photo script did.

Tool set: `ToolBox.focus`, 10 tools — set_timer / set_brightness /
get_brightness / schedule_notification / cancel_notifications /
list_pending_notifications / write_note / read_notes, with set_torch and
vibrate as `set_`-prefix and device-action distractors.

| beat | say | expect |
|---|---|---|
| 1 | Set a timer for 25 minutes. | `set_timer(1500s)` — card appears |
| 2 | Remind me to stretch in half an hour. | `schedule_notification(1800s)` |
| 3 | What notifications are coming up? | `list_pending_notifications`, answer lists beat 2 |
| 4 | Remember this: I stopped at page 128. | `write_note` |
| 5 | Dim the screen — I need to focus. | `set_brightness`, the screen visibly dims |
| 6 | Silence all my notifications and set a one-hour focus timer. | `cancel_notifications` → `set_timer(3600s)` — the chain |

日本語版:

| beat | 言う | 期待 |
|---|---|---|
| 1 | 25分のタイマーをかけて。 | `set_timer(1500s)` |
| 2 | 30分後にストレッチするのを思い出させて。 | `schedule_notification(1800s)` |
| 3 | この後どんな通知が来る? | `list_pending_notifications` |
| 4 | 覚えておいて。128ページで止まってる。 | `write_note` |
| 5 | 集中したいから画面を暗くして。 | `set_brightness`、画面が目に見えて暗くなる |
| 6 | 通知を全部止めて、1時間の集中タイマーをかけて。 | `cancel_notifications` → `set_timer(3600s)` |

Design notes (why these wordings)

- Beat 6 is written in call order — "silence … and set …" — because the
  models that chain follow the sentence. The 1.2B is expected to stop
  after the first call (it never chains, measured twice); if so the
  recorded cut either keeps the graceful single call or stars a chaining
  model for this beat.
- "Remind me" must route to `schedule_notification` while "Remember
  this" routes to `write_note` — the remind/remember pair is this pack's
  undo/revert. If one absorbs the other on device, the fix is renaming,
  not rewording (see recipes).
- Dim beat is late so most of the take is filmed at full brightness.

Recording notes

- Launch with `--scenario focus`.
- Grant notification and alarm permission **before** the take —
  `schedule_notification` and `set_timer` both prompt on first use.
- Timers are real AlarmKit alarms and notifications are real: cancel
  leftovers between takes or beat 3 lists the previous take's schedule
  (`cancel_notifications` by voice is the fastest cleanup).
- Beat 5 really dims the screen — check the recording exposure survives
  it; raise brightness again between takes.
- Focus mode on, phone cooled, same as every pack.
