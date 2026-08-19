# Recipes: getting a small model to call your tools

Patterns that survived contact with real devices. Each one states what to
do and the measurement or failure that earned it. Sizes below: "small"
means 1–3B running on the phone. Recipes from 2026-08-19 onward include
failures measured on Apple FM via the Mac lane (the same model family,
Catalyst build, `ios/bench/run-mac.sh`) — routing evidence, gathered
without a phone.

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

## Tell a model that can see to look first

Apple's model reports the vision capability and describes a photo
perfectly with no tools in the session — and, with tools and our stock
instructions ("prefer a tool over guessing, call it instead of answering
yourself"), it removed the background from a mountain range because a
beat said "if there's a person…". The instructions written for a blind
router are the wrong bias for a model that can see. Vision packs get
their own: look first; a conditional is answered by the pixels; when the
condition is not met, say so and call nothing. Same photo, same tools:
the conditional then held (no text → no note; a person → cut out).

## Label attachments the way the model will name them

`ImageReference` is how Foundation Models lets the model name the picture
a tool should act on. Attachments labelled `photo` were referenced as
`image` in every call — the model reaches for the label its own docs use
(image-0, image-1) — and nothing resolved. Use the label the model will
say, and resolve a miss to the newest image in the transcript: with one
photo in play there is only one thing it can mean, and a demo should not
die on the spelling of a label.

## Beat order is beat logic when the model sees its own work

Attaching the photo as it is now — edits included — is what makes "a
little more" mean more; it also means a makeover before the conditionals
leaves them nothing to do (the already-cut-out portrait got rotated 180°
by "if there's a person, remove the background"). Conditionals first,
makeover and save last.

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
answers with. And a canned result that *echoes specifics* can contradict
the call: `go_to_page(5)` came back as the canned "on page 3 — Rent and
Deposit" and the model, quite reasonably, called it again. Where the real
result would echo an argument, the fake stays neutral: "on that page now".

## The argument's name is part of the contract

Two failures, one shape, same morning (Apple FM, Mac). A volume fader
argument named `percent` ("new level 0–100, 'a bit quieter' is about 15
less") received **5** — the model sent a step, not a position; renamed
`level`, "where the fader ends up", the same request landed at 55. A
speed argument named `multiplier` turned "half speed" into **2** — the
model multiplied duration, not speed; renamed `speed` ("0.5 plays at
half speed"), it landed at 0.5. The guide text was right both times and
lost both times: the model reads the *name* first. Name the argument as
the value the user's sentence denotes, not as the operation applied to
it.

## Take the target as an argument when the model skips the setup call

The video pack modeled "make the second clip slow motion" the way the
app's UI works: tap the clip (`select_clip`), then act. Apple FM skipped
the tap and called `set_clip_speed` directly — which would have slowed
the *selected* clip, silently the wrong one. Chains that exist only to
set an implicit target don't survive; the action tool now takes the clip
as an optional argument ("omit for the selected clip") and the direct
call is the right call. Selection state is for the pronouns ("their",
"them", a silent bulk action) — not for arguments the sentence names.

## A new tool re-routes old sentences

Adding `search_orders` (find orders by customer) to the store pack broke
cases that had nothing to do with it: "Refund order 1007" now searched
first, "how many orders are waiting?" — a no-call case — called it
twice, and one search "helpfully" fulfilled the unfulfilled order it
found (the eagerness recipe, again). A tool list is one routing surface:
every addition moves the wells. Re-run the pack's cases when the menu
grows — this is exactly what the cases are for, and on the Mac lane it
costs minutes.

## Asking back must be licensed, and narrowly — best of all, routably

By default Apple FM does not ask for a missing required argument in a
state pack — it invents: "Add a caption." got a made-up caption,
"Refund the order." a made-up-plausible number. One instructions
sentence ("ask instead of inventing") flipped it — too far: it then
asked for a duration the request had already given ("for the first
three seconds") and for a speed "slow motion" already implies. The
sentence that held: ask **only** when something required is truly
absent, and *never about a detail the request or the state already
gives*.

The stronger fix was structural: an `ask_user(question)` **tool**, so
asking is routed like any other capability and the bench can score the
call. With it in the set, "Refund the order." became
`ask_user("which order?")` where prose licenses had produced an invented
number. What remains measured: the records packs like to *look first,
ask second* (a finder call and then ask_user — half right), and Japanese
requests still get an invented value mid-chain more often than English
ones. The ask-back cases (`expectAsk`) keep all of it scored.

## A confirm argument holds until the user's words are the tool's verb

Destructive tools got a `confirm` argument ("pass false unless the user
has already said yes; false shows them what will happen"). Measured on
the same afternoon: `refund_order` **held** — "Refund order 1007." came
in as confirm false and the model relayed the confirmation question —
while `checkout` **collapsed**: "Check out." arrived as confirm *true*,
order placed on the first ask, in both languages. The difference reads
as consent: when the user's own words are the tool's verb, the model
takes the request as the confirmation. Rewording the guide ("false on
the first call, always") did not fix checkout and broke refund — see
the noise-floor recipe. For a verb-named destructive action, do not
expect an argument to hold the gate; gate it in the app (the tool's
false-branch is the app's own confirmation dialog either way).

## Undo must own the going-back words

`undo_last` in every pack, described "Undo the last change." Asked
「やっぱりやめて」 after a mix change, Apple FM did not call it — it
**walked the change backwards by hand**: re-set four faders to their old
values and removed the effect, one call each. In the cart, "undo that"
became `remove_from_cart`. The same primitives instinct that walks past
`make_reel`: given a goal it can reach with tools it trusts, the model
re-derives the steps rather than calling the meta-tool. Manual reversal
is *almost* right — until the history and the model's memory of the
change disagree. If undo matters, put the going-back words in its
description, expect the by-hand reversal anyway, and measure it.

## Instructions have a noise floor — put contracts in the tools

Three rounds of rewording one instructions sentence — "after a finder
returns, stop" versus "…then make the action call" — swung the store
pack 27/44 → 22/44 and back, while identical builds varied by ±2–4
cases per pack between runs. Below that floor, prompt surgery is
indistinguishable from noise: the traits underneath (a spurious second
call after Japanese finders, a tool grabbed on no-call questions) did
not move for any wording tried. What did move behavior, every time, was
structure at the tool boundary: argument names, enums and steps,
per-argument guides, gates, an ask tool. Spend wording effort there; a
single Mac smoke run ranks packs, not sentences.

## State answers what the state contains — say what it doesn't

The docs pack's state names each page by its first line. Asked 「敷金は
何ページ?」 (which pages mention the deposit?), Apple FM answered "page
3" straight from the *titles* — "Rent and Deposit", translated — without
searching, and could not know the deposit is also on page 4. The
instructions had said "answer questions about the document from the
state"; the state's titles looked like enough. The line that fixed it:
"the state lists page titles, not their contents — a question about what
the document says needs search_document." A state block is an implicit
claim of completeness; when it summarizes, say what it leaves out, or
the model will answer content questions from the summary.
