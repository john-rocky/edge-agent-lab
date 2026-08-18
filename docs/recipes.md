# Recipes: getting a small model to call your tools

Patterns that survived contact with real devices. Each one states what to
do and the measurement or failure that earned it. Sizes below: "small"
means 1–3B running on the phone.

## Name the tool for the verb the user will say

The tool name is the strongest routing signal — stronger than the
description, stronger than the system prompt. `read_last_answer_aloud`
routed nothing; renamed `speak_out_loud`, the same model routed "Speak
that out loud." `cut_out_person` lost "Cut out the person." to
`flip_photo`; renamed `remove_background` — the word the world uses for
the job — the same request routed cleanly. Pick names by imagining the
sentence, not the API.

## Some intents have a gravity well — remove the competitor

On the 1.2B, every wording of "throw away all the edits" routed to the
one-step `undo_photo_edit`: "Undo everything", "Revert to the original
photo" (with `revert_to_original` sitting right there in the list), and
"Reset it" — which routed to `resize_photo` on the `res-` prefix alone.
The fix that worked was not better wording, it was removing the one-step
undo from the demo's tool set; the full revert then owned the going-back
words. When two tools shade the same intent, a small model gives
everything to one of them — decide which one deserves it.

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

## The tool-list ceiling is memory × count, not count

Routing across all 54 demo tools is past what a 1.2B can do ("read the
text in my photo" went to `get_audio_route`), but 15 well-named tools
route fine — the 1.2B scored 16/20 on the photo pack. The ceiling that
actually bit was the KV cache: the 2.6B's weights cap its context at
1024 tokens on the phone, the 15-tool list ate nearly all of it, and the
model died mid-thought on every real case (2/20, versus 17/20 with six
tools). Budget the tool list against the context the model leaves you,
not against the model's routing skill — on phone RAM, the bigger model
can be the weaker agent.

## Make signed ranges unmistakable

"Make it feel warmer" → Apple FM picked the right tool and passed
`amount: -100`, maximum cooling. A guide that reads "-100 (cooler) to
100 (warmer)" is apparently not enough at the moment of argument
filling. Prefer unsigned magnitudes plus a direction enum
(`direction: warmer|cooler, amount: 0–100`), or bake the direction into
the tool name — and let the bench's arg matchers catch what routing
metrics cannot: this call *routed* perfectly.

## If you fake tool results, fake them well

A canned result that doesn't look like the real thing causes retries:
Apple FM saw "(translated text)" come back and called translate twice
more. Canned results must claim success in the shape the real tool
answers with.
