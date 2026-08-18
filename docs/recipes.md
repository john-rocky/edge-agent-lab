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

The bench then measured the well: with the full set, the 1.2B reaches
1 of 10 going-back / cut-out cases, and refuses "Undo the last edit"
with undo in its list. Apple FM reaches 10 of 10 — wells are per model,
and the bigger router has different ones: "Remind me to stretch in half
an hour" goes to `set_timer` (right seconds, wrong tool) with
`schedule_notification` present, in both languages. The 1.2B's other
well is read-vs-write: "What did I ask you to remember?" → `write_note`.

## Take arguments in the user's units

Ask for seconds and the model has to multiply. Apple FM turned "25
minutes" into a question (what is the timer for?), 「25分」 into 150 s
and "one hour" into 600 s — twice; the 1.2B made "25 minutes" 15000 s
while getting 「25分」 right. The routing was perfect every time; the
arithmetic was not. Give the tool a `minutes` field (or a duration
string the app parses) and let the model copy the number it heard.

## Every required argument is a question waiting to be asked

`set_timer` requires a `label`; "Set a timer for 25 minutes" gave Apple
FM nothing to put there, so instead of calling it asked "what should
the timer be for?" — a lost beat that looks like a routing failure. The
Japanese photo cases lost three beats the same way to "how much, -100
to 100?". A required field with no default is a licence to stop and
ask; make it optional with a sensible default, or supply it in the app.

## Vague amounts land on the rail

"A bit brighter", "more contrast", "warmer": on a 0–100 scale Apple FM
answers 100, 100, 100 (and once -100). Small models don't interpolate a
vague adjective onto a numeric range — they pick an end. Offer the steps
the words already have — `a_little | more | a_lot` — and map them to
numbers in the app; keep the numeric field for requests that name one.

## When the model can't chain, chain in the tool

"Silence my notifications and set a one-hour timer" is two calls, and the
1.2B mashed the second into the first's arguments while Apple FM made
the chain and lost the hour on the way. Some jobs are always the same
three steps; put the steps in one tool. `start_focus_session(minutes)`
clears notifications, dims the screen, sets the timer and taps the
haptic — one name to say, one call, and the arithmetic and the ordering
belong to the app. Build the compound out of the single tools' bodies so
the two can't drift, and keep the singles in the set: the model picking
the one call over the three is the demo.

## Restraint is domain-relative

The 1.2B was the model that never grabbed a tool for "what is 2 plus
2?" or "when did I take this photo?" — then "how long should a pomodoro
break be?" became a 25-second timer, in both languages, with Apple FM
doing the same in English. A no-op that smells like the tool set is not
a no-op to a small model. Test restraint with in-domain questions, not
arithmetic.

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
tools). At 17 tools the list plus instructions is 1054 tokens and the
engine rejects every request before generating a token (0/30, 2 ms
each); at 10 tools the same model routes 8 of 10. Budget the tool list
against the context the model leaves you, not against the model's
routing skill — on phone RAM, the bigger model can be the weaker agent.

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
