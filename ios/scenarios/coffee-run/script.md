# Coffee run — demo script

The first recorded scenario (~/Downloads/lfmagent.mov, 2026-08-18,
LFM2.5-1.2B-Instruct_int4, 4/4 tool calls clean). A vague errand — where
am I, what's around, what does the menu say, take me there — handled
entirely on device.

| beat | say | expect |
|---|---|---|
| 1 | Where am I? | `get_location`, town-level answer |
| 2 | Find a coffee shop near me. | `search_places`, 3 real places |
| 3 | Read the text in my latest photo. | `read_text_in_latest_photo`, menu OCR |
| 4 | Open CAFE LA in Apple Maps. | `open_in_maps`, Maps foregrounds |

Recording notes

- Beat 4 last on purpose: it backgrounds the app and generation stops there.
- Name the place in beat 4; "that coffee shop" is out of the history window
  and sends the model searching again.
- The 2.6B runs a 6-beat cut (adds translate + speak); the 1.2B never
  routes speak — see docs/model-routing.md.
- Check the newest photo before recording: beat 3 reads it out loud.
