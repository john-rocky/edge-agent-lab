# Recipes: getting a small model to call your tools

Patterns that survived contact with real devices. Each one states what to
do and the measurement or failure that earned it. Sizes below: "small"
means 1–3B running on the phone.

## Name the tool for the verb the user will say

The tool name is the strongest routing signal — stronger than the
description, stronger than the system prompt. `read_last_answer_aloud`
routed nothing; renamed `speak_out_loud`, the same model routed "Speak
that out loud." Pick names by imagining the sentence, not the API.

## Never tell the model what it cannot do

Negative system-prompt lines are poison at 1.2B: told "you cannot speak
out loud yourself", the model answered "I'm sorry, but I can't speak out
loud" — and kept refusing after the sentence was removed. Positive
imperatives only ("When a tool matches the request, call it").

## Emit the tool list in the model's trained format

The OpenAI function envelope is not free: LFM2's bare
`{"name","description","parameters"}` format cut the same six tools from
376 to 253 prompt tokens, paid on every turn. Match the format the model
was trained on; keep an envelope option for models that expect one.

## Resolve references in the app, not in the model

A 1.2B routes "Translate 'good morning' to Japanese" perfectly — and
fails "Translate that": it cannot resolve a reference to the previous
answer into an argument. Don't ask it to. Keep the referent in app state
and give the tool access: `speak_out_loud` reads the last answer itself
(no arguments to fill); the photo tools edit "the photo" as a shared
session, so which pixels that means is the app's problem. What looks
like a routing floor is usually an anaphora floor.

## Expect eagerness to scale with capability

On requests where no tool applies, the strong routers grab one anyway:
Apple FM and the 2.6B both called a tool for "What is 2 plus 2?"; the
1.2B — the weakest router — was the only model that answered directly.
If your app has irreversible tools, over-triggering is the failure mode
to design against, and it comes with the better models.

## Budget invisible thinking

Hybrid-thinking models (LFM2.5) reason in a channel the runtime strips
from the stream. Unbudgeted, that is up to 40 s of silence that can end
in an empty answer — and `enableThinking: false` removes the cap instead
of the thinking. Always set a small thinking budget (the demo uses 32
tokens ≈ 2 s of silence).

## Fewer tools routes better

Routing across all 54 demo tools is past what a 1.2B can do ("read the
text in my photo" went to `get_audio_route`). Six distinct jobs route
reliably. Where the ceiling sits between 6 and 54 is what the 15-tool
photo pack measures next.

## If you fake tool results, fake them well

A canned result that doesn't look like the real thing causes retries:
Apple FM saw "(translated text)" come back and called translate twice
more. Canned results must claim success in the shape the real tool
answers with.
