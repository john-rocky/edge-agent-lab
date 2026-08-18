# Handoff — what the phone can leave behind

Tools: `ToolBox.handoff`, 9 (torch, sound, haptic, badge, clipboard r/w,
notification, note, brightness). No cases yet.
Launch: `--autorun --backend apple --scenario handoff`.

| beat | say | Apple FM, 2026-08-19 |
|---|---|---|
| 1 | Turn the flashlight on. | set_torch(on) ✓ |
| 2 | Turn it off and play the mail sound. | set_torch(off) → play_sound(mail) ✓ — the chain beat |
| 3 | Put a 3 on the app icon. | set_app_badge(3) ✓ |
| 4 | Copy 'meeting moved to 4pm' to the clipboard. | write_clipboard ✓ |
| 5 | Remind me in 30 seconds to check the oven. | schedule_notification(30 s) ✓ |
| 6 | Note this: the gate code is 2281. | write_note ✓ |

6/6, 50 s end to end. Recording note: the notification from beat 5
fires 30 s later — inside the next take if you go straight on.
