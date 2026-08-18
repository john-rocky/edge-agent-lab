# Chains — one sentence, several calls

Every beat wants two calls out of one sentence, on tools that have
nothing to do with each other. Two kinds of chain: the second call needs
nothing from the first (torch + battery), or exactly what the first
returned (OCR → translate, cafe → Maps). Tools: `ToolBox.chains`, 10.
Launch: `--autorun --backend apple --scenario chains`.

| beat | say | Apple FM, 2026-08-19 |
|---|---|---|
| 1 | Turn the flashlight on and tell me how much battery I have. | set_torch → get_battery ✓ (11 s) |
| 2 | Where am I, and how loud is it here? | get_location → measure_sound_level ✓ |
| 3 | What time is it in Tokyo, and in London? | get_current_time(Asia/Tokyo) → get_current_time(Europe/London) ✓ — both zones right |
| 4 | Read the text in my latest photo and translate it into Japanese. | read_text_in_latest_photo → translate ✓ (the photo had no text; it translated the "no text" line, faithfully) |
| 5 | Find a cafe near me and open the first one in Maps. | last on purpose — Maps takes the foreground and the run stops there |

Not run on the 1.2B yet; it is expected to stop after the first call
(measured twice on other packs). This is the pack that shows the gap.
