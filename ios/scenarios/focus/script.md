# Focus — demo script (benched, not yet recorded)

Compound device control: one vague sentence steering notifications, a
timer and the screen itself. The finale is two tools out of one sentence
— the chaining beat the photo pack never had. The bench has run these
wordings (Apple FM 12/20, 1.2B 12/20 — see docs/model-routing.md); what
it found about each beat is under the tables. Nothing recorded yet.

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

What the bench found, beat by beat (2026-08-18, before any recording)

- Beat 1, "Set a timer for 25 minutes.": Apple FM does not call — the
  required `label` becomes "what should the timer be for?"; the 1.2B
  calls with 15000 s. 「25分のタイマーをかけて」: Apple FM 150 s, 1.2B
  correct. Before recording, make `label` optional and consider a
  `minutes` field (recipes: user's units, required-argument questions).
- Beat 2, "Remind me to stretch in half an hour.": the 1.2B routes
  `schedule_notification`; Apple FM routes `set_timer` with the right
  1800 s — its well. Both languages.
- Beat 3 and 4 route cleanly on both models in both languages.
- Beat 5, dim: both route `set_brightness`; Apple FM picks 50 % in
  Japanese, which will not read as "dim" on camera.
- Beat 6, the chain: Apple FM calls cancel → set_timer in order every
  time but with 600 s for "one hour"; the 1.2B mashes the second call
  into the first's arguments (with the correct 3600 s inside). The
  recorded cut of this beat needs Apple FM plus a fixed timer schema, or
  drops the chain.
- The remind/remember pair (schedule_notification vs write_note) held
  on both models; the pair that broke on the 1.2B was read vs write
  notes ("what did I ask you to remember?" → write_note).
- Dim beat is late so most of the take is filmed at full brightness.

Timer note (2026-08-19): AlarmKit refuses this app — `requestAuthorization`
itself throws com.apple.AlarmKit.Alarm error 1, with or without countdown
faces — most likely because a single-target app has no widget extension
to host the alarm's Live Activity. `set_timer` now rings as a scheduled
notification when the system alarm is refused, so the beat lands; the
model sees "timer set for 1500s as a notification".

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
