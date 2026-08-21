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

Still true on Apple FM in the shopping pack: "Actually, make it just
one." never reached `change_quantity` in three configurations — the
model put a fresh ×1 in the cart, once by *composing* the set-operation
as remove_from_cart + add_to_cart (right end state, by hand). Renamed
`set_quantity` — the user's sentence is a set, not a change — the
English case routed on the first run, item name filled from the cart
line. The Japanese 「やっぱり1つにして」 still lands on add_to_cart:
the verb lever moved one language and not the other.

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

The ladder run (2026-08-20) measured the removal wholesale: 票を切って
had reused an existing issue in four straight runs — search_issues,
then assign_issue, then an answer claiming the issue was created — a
JA create-verb well stable at 11, 20 and 41 tools. In a five-tool room
holding only create / comment / close, it calls create_issue with the
right title, priority and project, in both languages. The well is not
the verb: it is the competitor. When a create intent keeps landing on
a finder, the fix to try first is the room, not the description.

## Take arguments in the user's units

Ask for seconds and the model has to multiply. Apple FM turned "25
minutes" into a question (what is the timer for?), 「25分」 into 150 s
and "one hour" into 600 s — twice; the 1.2B made "25 minutes" 15000 s
while getting 「25分」 right. The routing was perfect every time; the
arithmetic was not. Give the tool a `minutes` field (or a duration
string the app parses) and let the model copy the number it heard.

The same failure in yen: a `min_amount` in raw yen asks a Japanese
request to expand 万 — 100万円以上 arrived as min_amount 100,000 *plus*
max_amount 1,000,000, the number split across both bounds (crm, Mac,
2026-08-20), while the English "a million yen or more" filled cleanly.
A unit the user never says is arithmetic the model must do, and the
failure is language-shaped.

Weekday words are the same trap wearing a calendar: with the state
pinning "Today: 2026-08-20 (Thursday)" — weekday included — "due by
Friday" arrived as 08-25 and "next Monday" as 08-28 (a Friday), across
runs, in both languages (pm, Mac, 2026-08-20). The weekday in the state
is still right (it fixed the Japanese Friday once, and the words need
their referent somewhere), but weekday→date is arithmetic, and the
model does it about as well as it multiplies minutes. The untried
structural fix is this recipe's own: let the date argument accept the
weekday word ("friday", "next monday") and do the calendar in the app.

The currency in a definition is part of the contract too — both ways
(store `--usd` recording, Mac, 2026-08-20). Outbound: with every
fixture and tool result in dollars, one leftover "in yen" in a guide
kept the *answers* in ¥ — "All six products are now set to ¥30"
against an all-$ screen, two takes running, gone the moment the guides
said dollars. Inbound: "Set them all to $30." grazed
adjust_product_price (whose guide showed "$5" examples) before
recovering to set_price, twice; "Set them all to 30 dollars." went
straight to set_price both times — the spelled-out word matches "New
price in dollars" the way "3,000 yen" had matched "price in yen". The
model routes and speaks in whatever units the definitions are written
in, not the units on screen.

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

On the big router the cost of count is different: CRM + PM + Commerce
merged into one 41-tool list produced exactly one domain misroute in
126 cases (Apple FM, Mac, 2026-08-20) — but the packs' wandering cases
wandered *longer* (a 12-call invented chain became 21; an ask case
rampaged through 13 calls). Count doesn't confuse this model's
routing; it feeds its eagerness — every added tool is another room for
a lost model to wander into. Expect scale to stretch failure chains
before it breaks selection.

The full ladder (the same cases at 5/10/20/41 tools, Mac, 2026-08-20)
gave that curve its shape: a step at each end, flat in the middle.
Every pack gained substantially below ten tools (crm 23/36, pm 26/36,
store 41/54 — 90/126 in aggregate against 70/126 at 41); from pack
size to twenty tools every pack was flat within run-to-run variance;
the 41-tool bill landed on two packs of three. The monotone axis is
chain length: the store's longest failure chain grew 7 → 9 → 17 → 21
calls across the four rungs. For an app developer the reading is:
under ~10 well-chosen tools buys real accuracy, 10–20 is a plateau
this router does not charge for, and what count never buys is safety —
the destructive-tail and confirm wells ride below every rung.

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

Better than neutral: reflect the *actual* arguments — a pure render over
the pack's frozen data (the bench's `respond` closure). That removes the
contradiction instead of the content, and it pays exactly where the
finder's own result answers the question: "Search for 'linen'" went from
no call at all to one clean call, and 「マルエツでいくら使った?」 was
answered by search_payee's own total instead of a spurious follow-up
report. What it does *not* fix: the spurious second call after a Japanese
finder (categorize/flag piled onto "show me" with perfectly good rows on
screen — eagerness is not starvation), and it *interacts* with a "report
what it found and stop" instruction — a finder result worth reporting
makes the model report and stop mid-chain. Echo dynamically, and drop any
stop-after-finder line in the same pass (measured across inbox, store,
money on the Mac lane, 2026-08-19; crm re-ran the whole experiment on
2026-08-20 — its neutral fakes put a get_opportunity tail on every
Japanese finder, sent one English request through five searches the
neutral line never answered, and had the final answers confabulating
¥1,500,000 deals that do not exist; the echo bought +5 of 36 and fixed
exactly that bucket).

The drop is not free everywhere: in the shopping pack — static neutral
fakes, and finder cases that *end* at the finder — deleting "after a
search returns, report the results and stop" released sort_results
tails onto search and filter in both languages, three new failures with
one signature; restoring the sentence put the tails back under. The
line is poison where it stops a chain the case needs, protection where
the finder is the deliverable. Decide per pack by where its cases end,
not by the recipe's last victory.

Honest in shape, honest in *state* too: a bulk fake that answers
"snoozed the selected messages" while the case's state says "Selection:
none" scores a trajectory the real app would refuse. A fake cannot
change the model's first call — the result arrives after it — so
making the fakes selection-aware (primed from the case state, flipped
by the finder echoes) moved no scores at all; every case that passed
had made the right calls anyway. What it bought is the failure's true
face, and one finding: told "nothing is selected — list, search or
filter first", Apple FM relays the refusal in its answer and stops.
It does not call the finder it was just told about. A small model does
not repair after a refused call; the first call has to be right.

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

Range bounds obey the same law: "anything due by Friday?" put its date
in `due_date_from` three runs straight, in both languages — the wrong
end of a symmetric pair. Renamed `due_by` — the sentence's own word —
both languages filled the right slot on the next run (pm, Mac,
2026-08-20). The name fixed the slot and only the slot: the date inside
it stayed wrong (see the units recipe on weekday arithmetic).

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

An argument guide's example is invent-fodder. Shopping's "Add it to the
cart." — nothing named, no results in the state — was answered by
searching for "wireless earbuds", the example phrase in search_catalog's
own guide ("What to look for, e.g. wireless earbuds"), then buying
result 1, in both languages. Removing the example didn't make the model
ask; it made the confabulation visible: the next runs searched for
"something", "phone", "laptop". The example decides *what* gets
invented, not *whether* — keep examples out of the guides of tools a
lost model reaches for, and expect the ask license to lose to a
plausible first call anyway.

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

A second gated verb in the same list breaks the gate a new way:
cancel_order joined refund_order (store, Mac, 2026-08-20) and "Refund
order 1007." stopped calling anything — the model asked "Confirm the
full refund?" in prose, both languages, both runs, where it used to
make the confirm-false call and relay the tool's own question.
Confirmation became a pre-call habit, and a prose question advances no
state machine. Cancel itself arrived once as ask_user and once as
confirm *true* (the verb-as-consent collapse, again). One gated verb
held; two taught the gate as a ritual. The app-side dialog is the only
gate that survives every shape.

Shrinking the list does not restore the gate. In a five-tool room
holding only refund, cancel and the order finder (the ladder run,
2026-08-20), the pair scored 1/8: English refund and cancel still
called nothing and asked in prose, Japanese called refund with confirm
*true* on the first ask, and cancel misrouted to refund outright. The
same run pinned the worst shape as count-independent: "Find Tanaka's
orders." — a pure read — grew a refund confirm:true tail at 5 and 22
tools and a cancel tail at 41. The gated pair is a hazard at every
list size it appears in; the app dialog is not a mitigation but the
mechanism.

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

## The look-first prefix is character — wording will not remove it

On an id-acting pack (crm), Apple FM opens the record before touching
it: "Move O3 to negotiation." — the id in the sentence — arrives as
get_opportunity(O3) and then the correct update, and the same prefix
rides before amount changes, notes and undo in both languages. Dynamic
echoes removed the *tails* after finders and left the prefix. Three
wordings of the id contract ("no search call first"; per-argument "no
search or get call first"; "make the action call directly, nothing
before it") left it too — and the aggressive third popped three other
wells while it was at it: both no-call cases started sweeping search,
the Japanese ask case invented an id, and undo became a by-hand stage
reversal (Mac, 2026-08-20). A license that pushes one well down pops
others. The prefix is the records packs' look-first habit with a get
tool to spend it on: expect it from a strong router, score it as the
extra call it is, and spend the wording budget elsewhere. The ladder
run put a floor under "character": in a five-tool room (get, amount,
assign, plus the rails) the id cases still open with get_opportunity —
three of six, both Japanese id-act cases among them. No list is small
enough to starve the habit as long as the get tool is in it.

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

The floor is about rewording one text; *whose* text is above it. At 41
tools the merged business list ran twice with each case's own pack
instructions pinned and twice with one honest merged text — the same
contracts, stated once for a three-app workspace: pinning is worth
+5/126, every point of it in the CRM. The sentences barely differed;
the identity did. "You are operating the user's CRM" scopes 案件 to
the pipeline (merged, it went to search_contacts — a within-domain
entity misroute), keeps a how-many question on the state's counts, and
keeps the ask-back license attached to its cases (merged, ステージを
更新して advanced seven deals uninstructed). The pack that never moved
is the one whose find-first / act-direct contract rides in its state
line: a contract survives the merge only where it lives outside the
instructions.

## The state line is instructions — don't let it teach the well

The inbox pack's worst score (15/34) was blamed on search_mail's gravity:
a search before replies, opens and deletes the state already numbered.
The well had a teacher: every message ended "Selection: none — list,
search or filter first, then act" — written for the bulk tools, read as
the workflow for everything. Splitting the sentence by tool class
("Only the bulk tools (archive, snooze, flag, mark read) need a list or
search first; number tools act straight on the numbers above"), saying
the same on each number argument's guide ("from the state's list — no
need to search first"), and deleting the instructions' stop-after-finder
line took the pack to 25/34 in one round — the whole number-tool family
went direct in both languages, and both no-call cases passed for the
first time (the count was read from the state instead of refetched).
Ten cases is far above the ±2–4 noise floor; the same floor swallowed a
follow-up round of extra description sentences, which came straight back
out (the committed config lands at 23/34 — the structural gain minus the
noise). The state opens every message: whatever workflow it names
outranks the tool guides, so make it name the contract, not a habit.

Applied to the money pack the next session, the same split taught a new
well: "Only the bulk tools (categorize, flag) need a list, search or
filter first" put the act-tools' names in every message, and every
finder in both languages grew a categorize + flag tail — 22/30 → 16/30,
a brand-new failure signature made of exactly the two tools the line
names. A two-tool parenthetical reads as a to-do list where inbox's
four-tool family read as a class. What won was saying nothing: a bare
"Selection: none.", the finder-first contract left to the instructions'
scoped sentence and the bulk tools' own error results, took the pack to
27/30 — its best — with both no-call cases passing and the English
tails gone. The direct-action clause is the safe half of the split:
store's "refund_order acts straight on its order number" routed
注文1007を返金して directly where it had asked first. Split the state
line by tool class when the classes are big enough to read as classes;
when the bulk family is two tools, name no tools at all.

## Canned data must be findable in every language the pack tests

「マルエツでいくら使った?」 routed perfectly — search_payee, one call —
and the app answered "no transactions found" over a month of rows,
because the canned payee is "Maruetsu" and `contains` knows no kana.
The bench scored it a pass: the JA case deliberately leaves the payee
matcher open (the model may say マルエツ or Maruetsu), so the score
checks the call, not the answer. A kana→romaji step in the search tool
(the same normalization a real search bar does) turned the same call
into the right ¥26,190 in both languages. Grep your canned data for
every name the non-English cases can utter — an empty result that
routes cleanly is the failure a routing bench is structurally blind to.

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

The mirror case: the state must carry the words the user will point
with. Shopping's result lines were product titles only; "Put the Sony
ones in the cart" could not be resolved from them (the brand lives in
the catalog, not the title), so the model searched "Sony" and paid two
extra calls. Brand-first result lines — "3 Sony Noise Cancelling
Earbuds" — made the same request one clean add_to_cart(3) in both
languages, held across three runs. Render into the state every handle a
person actually grabs a product by: the number, the name, the brand.

## Vague judgments land on the rail too — give the question an anyOf

Asked "too dark, too bright, too warm, too cool, washed out, dull, or
about right?" about photos with each of those defects injected, Apple FM
answered "about right" to every one — including a photo 1.4 stops from
black. Asked about the same photo with the escape removed — "too dark or
too bright? Answer with just one of the two" — it answered "Too dark.
The image is underexposed, with shadows that are too deep and lack
detail." The perception was there; the open question's escape option ate
it. The act-side twin, from the same day's polish loop: told "make an
edit if it still needs one, call nothing when it looks its best", the
model called nothing zero times in twenty-eight rounds — the escape
never taken in the act direction — and rephrasing the loop's reprompt as
"does it still need improving — yes or no?" produced the first genuine
stop.

The amounts recipe (vague amounts land on the rail) is one instance of
something wider: an open judgment collapses to a default — "about right"
when answering costs nothing, "one more edit" when the room offers
tools. Wherever a loop or a route hangs on the model's judgment, shape
the judgment like an argument: enumerate its answers, force one, and
keep the default you fear off the list. A judge that must say yes or no
can say no; a judge allowed to say "about right" always will.

## The aesthetic prior is a gravity well — the same edits whatever the photo

Handed a defect photo and "judge what this picture needs", Apple FM
applies nearly the same sequence every time — brighter, more contrast,
warmer, then auto_enhance — whatever the pixels say: exposure *up* on
the overexposed fixture, *warmer* on the orange one, and in four rounds
the desaturated fixture never saw the saturation tool. The op choice
comes from what photos-in-general want, not from what this photo shows —
even though the same model names the defect correctly when the question
is a forced choice. Perception existing is not perception steering.
Before building a perceive→judge→act loop on a small VLM, measure the
judge separately (a no-tools, forced-choice probe per defect) and then
the judgment→op mapping, and expect the well: the ops inside the prior
(brighten, warm, punch up, enhance) fire regardless of the picture, and
the ops outside it (darken, cool, desaturate) do not come even when the
pixels name them.

## The ritual's floor belongs to the room, and it ratchets

Teaching a tool to answer makes it get called more. The moment-seek
bench's canned check_moment learned the real check's semantics — a
verdict word instead of a refusal — and its own call rate went from 7
calls in 7 cases to 15 in 14, reproduced exactly across two runs of the
identical config; most of the new calls verify a search that had
already succeeded, and the stop contract did not move. The floor then
stayed up: 19/20, 18/20, 18/20 across three later rounds and two
binaries. A ritual's floor is a property of what the room offers, not
of what the instructions ask, and it ratchets — it did not come back
down when the tool got no further help.

Removing the tool does not remove the ritual either; the answering slot
refills. Taking check_moment out of a take's room ended every harm it
caused — the model denying its own search hit went 3/12 → 0/9, index
sweeps 2/12 → 0/9 — and the first beat immediately grew a `seek`
instead, in 9 of 9 runs, where none of the 12 runs with the check
present had seeked there. The model does not want *that tool*; it wants
something to do after an answer. So the lever is never a better answer
and rarely a better sentence: it is leaving nothing in the room worth
calling, and then designing for where the slot refills, because it
will.

The cheapest reading of "design for where it refills" is a free
occupant, and that was tested and is wrong. A no-argument `done` tool
returning one word, added to the pack and to nothing else, was called
**0 times in 92 cases across two rounds** while sitting in every run
record. The slot does not take just any occupant: the ritual feeds on
usefulness, and a result no later sentence can be built on is not a
candidate — where the slot did refill, it refilled with a tool that
comes back with a frame. A viable occupant has to be useful *and*
harmless, which is a much harder tool to write than a sink. One caveat
on the instrument before anyone repeats this: a bench that scores
`called == expected` fails a trailing sink call exactly as it fails a
trailing check, so a sink can measure there as neutral or costly and
never as a saving. (Check the attribution before crediting your change: a spurious
set_clip_speed vanished from the same nine runs and turned out to be a
Japanese-input habit visible in the bench with the full pack present.)

## A verb with a near neighbour routes to the neighbour

「動画を書き出して。」 — export the video — called `auto_captions` in
one run of three, failed to transcribe, and then refused to export at
all. 書き出す (export) sits one character from 書き起こす (transcribe),
so the verb points at the caption tool as readily as at the export one.
Two independent repairs both went 3/3: replace the verb
(「エクスポートして。」, katakana, no such neighbour) or give it a noun
to land on (「動画ファイルとして書き出して。」). Only the bare verb
failed. This is the gravity-well recipe read from the other side —
there the fix was removing the competing tool, here the competitor is a
homophone in the user's own sentence and the fix is in the sentence.
When a pack's demo or docs put words in the user's mouth, check every
verb for a near neighbour that names another tool in the room; when
they don't, expect the misroute and name the object.

## The reply follows the language of the instruction block

Not the request's language, and not the nearest turn's. A Japanese
request to a stage whose instructions are English comes back in English
— 1 of 11 runs answered Japanese. The same instruction sentence
rewritten in Japanese, same slot, took it to 6 of 10; the *identical*
Japanese sentence appended one line under the user's own turn moved
nothing, 0 of 5. All four conditions said the same thing, so content is
not the lever and proximity is not the lever: the preamble's own
language is. The effect is asymmetric, with English as the attractor —
an English preamble overrides a Japanese request, a Japanese preamble
does not override an English one (an English run under the Japanese
line stayed English 3 of 3). For anything that ships in two languages,
write the preamble in the language the user speaks and re-measure the
other one; and keep the line out of any instruction text a bench shares
as its control.
