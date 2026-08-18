# Sensors — what the phone can feel

Tools: `ToolBox.sensors`, 8 (location, place name, heading, motion
activity, sound level, air pressure, orientation, tilt). No cases yet.
Launch: `--autorun --backend apple --scenario sensors`.

| beat | say | Apple FM, 2026-08-19 |
|---|---|---|
| 1 | Where am I? | get_location ✓ |
| 2 | What's this place called? | describe_location ✓ |
| 3 | Which way am I facing? | get_heading → "the compass did not answer within 8s" → **get_orientation** → "you are facing upright" — the tool deadline fired and the model improvised a fallback |
| 4 | Am I moving right now? | get_motion_activity ✓ (still) |
| 5 | How loud is it here? | measure_sound_level ✓ (-24 dBFS) |
| 6 | How high up am I? | get_air_pressure ✓ — honest, "+0.0 m since launch" |

Beat 3 is the one to record: a sensor that doesn't answer, and the model
finding another way to say something true.
