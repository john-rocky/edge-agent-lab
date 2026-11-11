# Scenarios

| scenario | you say | what happens |
|---|---|---|
| [Coffee run](../ios/scenarios/coffee-run/) | "Where am I?" … "Open CAFE LA in Apple Maps." | location → places search → menu OCR → Maps opens. Recorded, 4/4 tool calls on a 1.2B |
| [Photo editing](../ios/scenarios/photo-editing/) | "A bit brighter." "Warmer." "Undo everything." "Remove the background." | 17 editing tools; edits stack, a whole chain reverts by voice, the subject lifts off the background. Benched on 3 models, recorded |
| [Focus](../ios/scenarios/focus/) | "Dim the screen — I need to focus." "Silence my notifications and set a one-hour timer." | Benchmarked on 2 models (12/20 each, different failures), not recorded yet. The last sentence needs two calls: Apple's model makes both but sets 600 s, and the 1.2B makes one broken call |
| [Field report](../ios/scenarios/field-report/) | "Read the text in my latest photo." "Remind me tomorrow at 9 to file the report." | gauge photo → OCR → note → next-morning reminder, fully offline. Pack built; bench and recording next |
| [Video editing](../ios/scenarios/video-editing/) | "Cut the first two seconds, make it vertical, and fade out at the end." "Split it at the playhead." "Turn it into a Reel." | a CapCut's menu, said out loud: 18 tools (incl. synthesized background music and the make_reel compound) on the newest library video. The model never sees a frame — the app's state opens every message and the tools take the numbers it names. Routing verified on Apple FM (Mac) |
| [Store](../ios/scenarios/store/) | "Which products have fewer than 5 in stock?" "Cut their prices by 10%." "Fulfil all the paid orders that haven't shipped yet." | a Shopify admin's menu over canned records: search / filter makes a selection, bulk actions act on it — records, not pixels; a second class of bench case (was the query right). 22 tools; routing verified on Apple FM (Mac) |
| [Audio](../ios/scenarios/audio/) | "The keys are a bit loud — turn them down a bit." "Solo the drums." "Fade out at the end, then export it." | a GarageBand mixer over four tracks the phone synthesizes and plays: faders are numbers the model reads from the state and moves; effects rebuild the graph mid-song; the mixer is on stage, faders visibly at their levels. 18 tools; routing verified on Apple FM (Mac) |
| [Documents](../ios/scenarios/docs/) | "Which pages mention the deposit?" "Delete the cover page." "Sign the last page." | an Acrobat / Goodnotes menu on a real PDF (PDFKit): pages named by their first line in the state, so "the cover" and "the last page" are numbers the model reads; highlights, watermark, ink signature, page extraction. 18 tools; routing verified on Apple FM (Mac) |
| [Shopping](../ios/scenarios/shopping/) | "Find wireless earbuds." "Add the second one to the cart — two of them." "Use the coupon SAVE10." | the buyer's side of the counter: numbered results in the state, the cart's arithmetic in the app. 12 tools over a canned catalog |
| [Money](../ios/scenarios/money/) | "What did I spend this week?" "They're all groceries — categorize them." "Find my subscriptions." | a household-budget app over a month of canned spending: finders select, categorize acts on the selection, the reports do the arithmetic. 11 tools |
| [Inbox](../ios/scenarios/inbox/) | "Archive all the newsletters." "Snooze the invoice from Kanda Goods until tomorrow." | mail triage over fifteen canned messages: find-then-act chains; drafts are written, never sent. 12 tools |
| [Vision](../ios/scenarios/vision/) | "If there's a person in it, cut them out." "Anything you'd fix? Do it." | the photo goes in with the words and the pixels pick the tool — Foundation Models vision, natively (`Attachment` in, `ImageReference` out). 5/5 on Apple FM |
| [Chains](../ios/scenarios/chains/) | "Turn the flashlight on and tell me how much battery I have." "What time is it in Tokyo, and in London?" | two calls out of one sentence, on unrelated tools. 4/4 on Apple FM |
| [Compound](../ios/scenarios/compound/) | "I need to focus for 20 minutes." "Give me my morning briefing." | one call, several APIs: notifications cleared + screen dimmed + timer; five readings in one. The model picks the one call over the three |
| [Briefing](../ios/scenarios/briefing/) · [Sensors](../ios/scenarios/sensors/) · [Handoff](../ios/scenarios/handoff/) | "Which way am I facing?" "Turn it off and play the mail sound." | quick packs on Apple FM — 17/17 beats; the compass timing out and the model falling back to orientation is the one to watch |
| [Android screen agent](../android/) | "open the notification history" | screenshot → local VLM → tap point → real tap → loop, on a Pixel 8a |

Input is not only typed: the chat has a microphone (SpeechAnalyzer,
words landing as they are said) and a paperclip (a photo goes in with the
message — Apple's model reads it natively, a LiteRT vision bundle through
the adapter). The stage's `--voice` takes every beat from the air.

Most iOS scenarios are **packs**: a tool set, a demo script, and benchmark
cases. Three of them are in the model table in the [README](../README.md#which-model-to-run). The app hosting
them is
[lfm-tools-ios](https://github.com/john-rocky/LiteRT-Models/tree/screen-agent/lfm-tools-ios)
— LFM2.5 behind Apple's `LanguageModel` protocol via a
[LiteRT-LM adapter](https://github.com/john-rocky/LiteRT-LM/tree/apple-fm-guided-constrained-decoding),
so the same session runs Apple's model or an open one: swap the backend,
keep the tools.
