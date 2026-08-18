# Briefing — what the phone knows right now

Tools: `ToolBox.briefing`, 7 (time, battery, power state, calendar,
reminders, steps, step chart). No cases yet; Apple FM only.
Launch: `--autorun --backend apple --scenario briefing`.

| beat | say | Apple FM, 2026-08-19 |
|---|---|---|
| 1 | What time is it, and how's my battery? | get_current_time → get_battery ✓ (a chain, unasked) |
| 2 | What's on my calendar this week? | list_calendar_events ✓ — eight events summarised, the noon one dropped |
| 3 | Anything left on my reminder list? | list_reminders ✓ |
| 4 | How many steps have I walked today? | get_steps_today ✓ |
| 5 | Chart my steps for the last 7 days. | chart_steps ✓ — the chart card lands on stage |
