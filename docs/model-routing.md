# Model routing observations

## The Mac lane (2026-08-19, Apple FM via Catalyst — smoke tests, not table rows)

The app builds for Mac Catalyst and Apple's model is available there,
tools and vision included — so a pack's routing is now measured the day
it is written, with no phone (`ios/bench/run-mac.sh`,
[raw JSONL](../ios/bench/results/2026-08-19-mac/)). Same model family as
the phone, different machine: these numbers guide pack design and do not
enter the device table below.

After six fix rounds across one day (the failures and their fixes are
recipes now — argument names, neutral fakes, ask licenses, finder
discipline, the confirm gate, undo ownership, the noise floor), with
every pack now carrying ask_user, undo_last and — on refund / checkout /
delete — the confirm argument:

| pack | tools | cases | Apple FM (Mac) |
|---|---|---|---|
| video-editing | 18 | 40 | 34 |
| store | 22 | 54 | 36 |
| audio | 18 | 38 | 34 |
| docs | 18 | 42 | 37 |
| shopping | 12 | 34 | 24 |
| money | 11 | 30 | 27 |
| inbox | 12 | 34 | 25 |
| crm | 12 | 36 | 20 |
| pm | 11 | 36 | 21 |

216/262 overall (store, money, inbox and shopping re-measured in the
evening and late rounds below; the other three packs keep their morning
numbers). Identical
builds vary by ±2–4 cases per pack between runs — a single run ranks
packs, not sentences (the noise-floor recipe). What remains is mostly
the model's character, not the packs': it grabs a tool on no-call cases,
it adds a spurious second call far more often in Japanese than in
English, it walks a compound's steps by hand rather than calling
make_reel — and, the same instinct, walks a *change* backwards by hand
rather than calling undo_last. The confirm gate held for refund and
collapsed for checkout ("Check out." arrived as confirm true — the
user's words read as the consent).

The evening round (same day) attacked the two lowest packs with
structure, one lever per run. The finder fakes now echo the real
arguments — a pure render over the frozen canned data (the fake-well
recipe) — which fixed the cases a finder's own result answers and
nothing else; the inbox state line names the contract per tool class
instead of a find-first habit, every inbox number argument's guide says
"no need to search first", delete's false branch stopped commanding its
own confirm-true call (the model had been self-confirming with it), and
search_payee normalizes kana (「マルエツ」 had routed perfectly into an
empty answer over a month of Maruetsu rows). inbox 15 → 23 — the
search_mail well collapsed for the number tools in both languages, and
both no-call cases now pass, the first pack where they do. money
20 → 22, store 31 → 32. What held still through every result shape and
wording tried: the Japanese spurious second call (categorize/flag piled
onto a finder that returned perfectly good rows — eagerness is not
starvation), "Snooze it." acting instead of asking, and
「今のを取り消して」 deleting instead of undoing — character, not packs.
Raw JSONL: [echo-only](../ios/bench/results/2026-08-19-mac-echo/),
[structure round](../ios/bench/results/2026-08-19-mac-r2/),
[final config](../ios/bench/results/2026-08-19-mac-r3/) and
[inbox final](../ios/bench/results/2026-08-19-mac-r4/).

The late round (same night) took the inbox state-line recipe to store
and money — and measured its edge. Store's split ("only the bulk tools
need a search or filter first; refund_order acts straight on its order
number"), plus dropping its stop-after-finder line and "no need to
search first" on refund's number guide: 32 → 33, with 注文1007を返金して
now routing straight to refund_order where it had asked first — though
the call arrived confirm-true, the gate collapsing exactly as the
confirm recipe predicts. Money got the same split and dropped six
cases (22 → 16): "Only the bulk tools (categorize, flag) need a list,
search or filter first" named the act-tools in every message, and
every finder in both languages grew a categorize + flag tail. The fix
that won was a bare "Selection: none." with the instructions restored
verbatim — one variable against the 22/30 config — landing 27/30, the
pack's best: both no-call cases pass, the double report call and the
English tails are gone. What still stands: the Japanese categorize/flag
pair called together on selection cases, and 予算を設定して answering
with a plausible tool instead of ask_user. Raw JSONL:
[split round](../ios/bench/results/2026-08-19-mac-r5/) and
[bare state line](../ios/bench/results/2026-08-19-mac-r6/).

Last round of the night: the bulk fakes stopped lying about the
selection. A per-case flag primed from the case's state line (finder
echoes replace it; the store's tracks products vs orders) gives a bulk
call with nothing selected the real app's refusal instead of "snoozed
the selected messages". Scores held or drifted within the floor —
inbox 25, store 35, money 27, 215/262 committed — confirming the fake
was mis-scoring nothing that passed; what it changes is what failure
looks like. The new measurement it bought: after a mid-chain refusal,
Apple FM relays it honestly ("the current selection is empty, so
nothing was archived") and stops — it neither retries with the finder
it skipped nor asks, even though the refusal names the repair ("list,
search or filter first"). Repair-after-refusal is not in the model's
repertoire; the first call has to be right. Raw JSONL:
[honest fakes](../ios/bench/results/2026-08-19-mac-r7/).

The shopping round (the next session, same date) took the lowest-ratio
pack from 23 to 24 of 34 in three one-variable runs — a small net move
hiding five attributable flips. What worked: the brand went into the
state's result lines ("3 Sony Noise Cancelling Earbuds"), and "Put the
Sony ones in the cart" became one clean add_to_cart(3) in both languages
(held across all three runs) where it had searched first — the state's
titles alone could not resolve a brand the user says. And
change_quantity, renamed set_quantity, caught "Actually, make it just
one." in English on the first run with the rename — the model had been
*composing* the set-operation out of remove_from_cart + add_to_cart, the
by-hand instinct again. What backfired, measured: deleting shopping's
"after a search returns, report the results and stop" — the deletion
that lifted inbox and store — released sort_results tails onto the
finder cases in both languages (three new failures, one signature);
restored, the tails went back under. The line is poison where it stops a
chain the case needs, protection where the finder is the deliverable.
What refused to move in any run: 「カートに入れて」/"Add it to the cart."
with nothing named still buys something instead of asking — the invented
query was the search guide's own example phrase verbatim until the
example was removed, after which the model searched for "something",
"phone", "laptop" (the example chose *what* was invented, not
*whether*); JA's 「やっぱり1つにして」 still lands on add_to_cart
(quantity 1 — which the real app reads as ×3); checkout still arrives
confirm-true; JA undo still walks backwards by hand. Raw JSONL:
[levers](../ios/bench/results/2026-08-19-mac-r8/),
[stop line restored](../ios/bench/results/2026-08-19-mac-r9/),
[set_quantity](../ios/bench/results/2026-08-19-mac-r10/).

The CRM round (2026-08-20) built the first business-wing pack to the
business-packs spec — 12 tools over a frozen quarter, every action
taking its record as an id argument, the state pinning a frozen today
so relative dates score as absolute ones — and measured it in four
one-variable runs. Static neutral fakes started it at 15/36: every
Japanese finder grew a get_opportunity tail, one English assign
flailed through five searches the neutral line never answered, and
the answers confabulated rows that do not exist (¥1,500,000 deals).
Dynamic finder and get echoes — the fake-well recipe, again — bought
+5 (20/36, the committed config) and fixed exactly the starvation
bucket. Two wording rounds against the remaining signature —
get_opportunity called *before* update / assign / note / undo, with
the id already in the request — moved nothing they aimed at, and the
aggressive one broke restraint where it wasn't aiming: "make the
action call directly, nothing before it" had both no-call cases
grabbing search sweeps, the Japanese ask case inventing an id, and
both undo cases walking the stage change backwards by hand (18/36);
reverted, the pack sat at 20/36 again with the get-prefix untouched
in both languages. The look-first prefix on id-acting tools is
character, not wording. What the planted instruments caught, stable
across runs: 受注にして routed to assign_opportunity with the owner
filled from the state row's *current* owner; 100万円以上 became
min_amount 100,000 *and* max_amount 1,000,000 (the 万 split); "We won
this one — mark it closed." arrived as stage *lost*; and "closing
this month" never got its close_date_to bound in either language.
Four definition-optimization targets for the evaluation program's A/B
loop. Raw JSONL:
[neutral fakes](../ios/bench/results/2026-08-20-mac-r11/),
[echo, committed](../ios/bench/results/2026-08-20-mac-r12/),
[wording round](../ios/bench/results/2026-08-20-mac-r13/) and
[guides reverted](../ios/bench/results/2026-08-20-mac-r14/).

The PM round (same day, the second business-wing pack) started where
the CRM round ended — dynamic echoes from the first run, the id
contract in the CRM pack's committed wording — and landed at 20/36 on
run one, the CRM level exactly. What its four runs added (r15–r18,
committed config 21/36, range 19–21): the get-prefix reproduced
verb-by-verb across the change_* family in both languages, as
predicted, and was not chased. "Due by Friday" landed in the *from*
bound three runs straight in both languages; renaming the arguments
due_from / due_by moved the date into the right slot on the next run —
the argument's name fixed the slot — while the date *value* stayed
wrong (Friday → 08-25, next Monday → 08-28) even after the state's
frozen today grew its weekday ("2026-08-20 (Thursday)", worth +2 once):
weekday words reach the right argument and the wrong date, a model
floor the definition loop should try app-side parsing against. New
character, all stable: Japanese 票を切って never reached create_issue
in four runs (the model searched, then *re-purposed an existing issue*
— assigned and re-prioritized APP-6 and reported it created); the
Japanese undo case failed three different ways in three runs (manual
reversal to a *guessed* old value — P1 where the truth was P3 —
manual reversal again, then a flat "I cannot undo, the board only
shows the current state" with undo_last sitting in the list); one
English run swept 57 consecutive search_issues calls over two minutes
without ever acting on the id the sentence named; and create_issue
omitted the P1 the sentence gave while the answer *claimed* P1 — the
call and the prose disagree, and only the call is real. Raw JSONL:
[first run](../ios/bench/results/2026-08-20-mac-r15/),
[weekday](../ios/bench/results/2026-08-20-mac-r16/),
[due_by rename](../ios/bench/results/2026-08-20-mac-r17/) and
[committed replicate](../ios/bench/results/2026-08-20-mac-r18/).

The Commerce round (same day) extended the store pack to the business
spec — get_product, adjust_product_price (update_price renamed, now a
percentage *or* a yen amount: the relative half beside set_price),
cancel_order (a second confirm-gated destructive verb, completing the
fulfil / refund / cancel triangle), search_customers and
create_discount; 18 → 22 tools, 44 → 54 cases — and measured the
re-routing bill on two runs (35 and 36 of 54; the old 44 cases sit at
30–31 against their 35 baseline). The headline is what the second
gated verb did to the first: "Refund order 1007." now calls **nothing**
— the model asks "Confirm the full refund?" in prose, in both
languages, both runs, where it used to make the confirm-false call and
relay the tool's own question. With one gated verb the contract held;
with two, confirmation became a *pre-call habit* and the state machine
never advances. Cancel itself showed the third shape: 注文1012を
キャンセルして arrived once as ask_user and once as confirm *true* on
the first call (the user's verb read as the consent — checkout's
collapse, on a new verb). The pair instrument also fired on schedule:
全部3,000円にして (an exact price) was captured by adjust_product_price
with confabulated arguments (percentage −100 *and* amount −3000, the
answer claiming ¥3,000 success), and Japanese finders grew
refund_order and get_product tails they did not have before — a tool
list is one routing surface, and five additions moved wells that had
been stable for a day. Raw JSONL:
[extension](../ios/bench/results/2026-08-20-mac-r19/) and
[replicate](../ios/bench/results/2026-08-20-mac-r20/).

The cross-domain round (same day, the business wing's first scaling
measurement — evaluation program #2/#3) merged CRM + PM + Commerce
into one 41-tool list (rails deduplicated) and re-ran all 126 cases
against it, each pack's own instructions pinned via the runner's new
`--instructions` flag so tool count is the only variable. Native
baselines 20 + 21 + 36 = 77/126; merged: crm 21, pm 16, store 33 =
**70/126**. The headline: exactly **one** true domain misroute in 126
cases — 田中さん担当の票を見せて reached for the CRM's search_contacts
instead of the board's search_issues — so at 41 tools this router
keeps the domains apart almost perfectly. Where the −7 actually went:
*within-domain wandering got longer*. The store's Japanese
invented-chain cases stretched to 21 and 18 calls (reprice / tag /
status / inventory / fulfil sprees before finally refunding), a PM ask
case rampaged through 13 calls, and finders grew heavier tails — every
added tool is another room for a lost model to wander into. The
confirm-hoisting (refund and cancel answered with a prose question and
no call) survived the merge unchanged. Count pressure on this model
shows as chain length, not domain confusion — the envelope's first
data point. Raw JSONL:
[cross-domain](../ios/bench/results/2026-08-20-mac-r21/).

The ladder round (same day, evaluation program #1) filled the curve in
downward: the same cases at 5 / 10 / 20 tools, subsets cut from the
41-tool business list by name (the runner's new `--only` flag), each
pack's instructions still pinned. A 5-tool subset cannot hold a whole
pack, so each low rung is a family of "mini-app" groups
([ladder.json](../ios/bench/ladder.json)) and every case runs in the
one group that holds its correct tools (ladder.py's first-match
partition — a subset without the case's answer measures nothing). The
curve, pass/cases per pack: **crm 23 → 20 → 20 → 21** (5/12/20/41),
**pm 26 → 21 → 21 → 16** (5/11/20/41), **store 41 → 35 → 36 → 33**
(5/10/22/41); in aggregate **90/126 at five tools against 70/126 at
41**. The shape is not a slope — it is a step at each end. Every pack
gains substantially below ten tools (+3/+5/+5, against the ±1.5
run-to-run variance pm's three baseline runs showed); from pack size
to twenty the curve is flat everywhere, even with nine foreign
CRM tools sitting ahead of PM's own in the list; the 41-tool bill
lands on pm (−5) and store (−3). Chain length is the axis that moves
monotonically: the store's longest chain grows 7 → 9 → 17 → 21 calls
across the four rungs (mean 1.28 → 1.48 → 1.56 → 1.91). Where the
five-tool gains come from is the gravity-well recipe measured
wholesale: wells close when the competitor leaves the room. 票を切って
had reused an existing issue in four straight runs (search_issues →
assign_issue); with only create/comment/close in the room it creates,
correctly, in both languages — and the undo cases and comment cases
return the same way. What five tools does *not* fix: the aftercare
group (refund / cancel / search_orders) scored **1/8** — English
refund and cancel still hoist (zero calls, a prose "Confirm?"),
Japanese flips to confirm *true* on the first call, and "Find Tanaka's
orders." still grows a destructive tail (refund confirm:true at 5 and
22 tools, cancel at 41). Fewer tools shorten the wandering; they do
not make the remaining calls safer — and the destructive-tail and
look-first habits (crm's id cases still open with get_opportunity at
five tools) ride below every rung of the ladder. Raw JSONL:
[crm](../ios/bench/results/2026-08-20-mac-r22/),
[pm](../ios/bench/results/2026-08-20-mac-r23/),
[store](../ios/bench/results/2026-08-20-mac-r24/).

The instructions round (same day, the A/B the cross-domain round left
open: one merged text, or each pack's own?) reran the 41-tool list
with a single business instructions text in place of r21's per-pack
pin — the shared skeleton stated once, each pack's load-bearing
contracts kept, a route-by-entity hint added: what a developer merging
three packs would actually write. Twice: **65/126 and 65/126 against
the pin's 70/126**, the entire bill landing on the CRM (crm 21 → 16 →
16; pm 16 → 16 → 17; store 33 → 33 → 32 — two identical unified runs
flip ±6 cases against each other, so pm and store moved nothing net).
Four CRM failures recur in both unified rounds and name what the
pinned text had been doing. 田中さんの案件を見せて goes to
search_contacts — the bench's first *within*-domain entity misroute,
and it lands in the same well as r21's one *cross*-domain misroute
(票を見せて): a person's name plus a generic workspace pulls toward
contacts, and the pinned text's identity sentence had been what held
案件 to the pipeline. "How many deals are open right now?" calls the
finder instead of reading the state's count — the counts-answer-how-many
sentence survives verbatim in the merged text and holds less, said
once for three apps (pm's JA how-many broke the same way, both
rounds). ステージを更新して — no record named, the ask-back case —
invents targets instead of asking: r25 marked two negotiation deals
won; r26 probed all eight deals and advanced seven, announcing "All
opportunities have been moved to their new pipeline stages" — the
worst uninstructed write the bench has produced. And the JA
multi-step's stage update is displaced by a get_opportunity
look-first. PM is the counter-story: five stable fixes in both rounds
(the JA ask, undo and multi cases the pin had lost, and create_issue
finally carrying its P1) against three stable breaks — where a pack is
already at its 41-tool floor, one text moves *which* cases fail, not
how many. Store never moved at all — and it is the pack whose
find-first / act-direct contract rides in its state line rather than
its instructions. The envelope's second data point: at 41 tools,
per-pack pinning is worth +5/126 over the honest merged text, and the
price concentrates where a pack's contracts live nowhere but the
instructions. Raw JSONL:
[unified](../ios/bench/results/2026-08-20-mac-r25/) and
[replicate](../ios/bench/results/2026-08-20-mac-r26/).

The loop round (same day, the first measurement past the input layer —
ROADMAP's goal-driven archetype) put a multi-turn mode in the runner:
round one attaches a photo with one injected defect (dark / bright /
cool / warm / flat / dull / good, generated by the app's own filter
recipes run backwards), every later round re-attaches the photo as the
model's edits left it and asks again, a round with no tool call is the
stop, and the case's ground truth is the op that fixes the defect and
the op that deepens it. The room is the 15-tool vision pack with real
edit bodies — the one deliberate break with the bench's all-canned
rule, since the model must judge its own actual output. Apple FM held
the per-round contract perfectly (one edit per round, every round) and
**never stopped: 0/7 at four rounds, 0/2 at six, prose declaring "It
is done" in the same round as the call**. The edits are a ritual, not
a judgment — brighter, more contrast, warmer, auto_enhance, whatever
the fixture: exposure *up* on the overexposed photo, *warmer* on the
orange one, saturation never touched on the desaturated one. The
perception controls (polish-see, the same fixtures behind one
question) locate the failure: with any tools in the room the question
itself becomes an edit call under both instruction sets; with no tools
the answer is "about right" to every defect — **and the same photo
gets "Too dark. The image is underexposed…" the moment the question is
a forced binary**. The perception exists, surfaces only under forced
choice, and never reaches the loop's op choice. Re-shaping the loop's
reprompt as a forced choice ("does it still need improving — yes or
no?") produced the first genuine stop (one of nine; the ritual
otherwise unmoved) — and one case died blowing the 8192-token window
after the model answered a round by fabricating an inline base64
image, which names the archetype's real on-device budget: iterations ×
attached images is a context spend, and a runaway answer spends it at
once. Recipes: "Vague judgments land on the rail too" and "The
aesthetic prior is a gravity well". Raw JSONL:
[open reprompt](../ios/bench/results/2026-08-20-mac-r27/) and
[replicate + horizon](../ios/bench/results/2026-08-20-mac-r28/),
[one-turn contract](../ios/bench/results/2026-08-20-mac-r29/),
[perception](../ios/bench/results/2026-08-20-mac-r30/) and
[forced choice](../ios/bench/results/2026-08-20-mac-r31/),
[forced reprompt](../ios/bench/results/2026-08-20-mac-r32/).

# On device (2026-08-18)

Measured on iPhone (iOS 27), CPU backend, bare tool-list format, thinking
budget 32 tokens, via [toolbench](../ios/bench/README.md)
([raw JSONL](../ios/bench/results/2026-08-18/)). Four scenario packs so
far: coffee-run (6 tools), photo-editing (15 tools, then 17), focus (10
tools) and field-report (10 tools, not yet run). The bench reproduced the
hand-run demo's routing table and corrected one conclusion — see
translate below.

| pack | Apple FM | LFM2.5-1.2B int4 | LFM2.5-2.6B int4 |
|---|---|---|---|
| coffee-run, 6 tools, 20 cases | 17/20 · 3 s | 15/20 · 4.4 s | 17/20 · 15.5 s |
| photo-editing, 15 tools, 20 cases | 14/20 · 2.7 s | **16/20** · 7.2 s | 2/20 · context overflow |
| photo-editing, 17 tools, 30 cases | **24/30** · 1.8 s | 17/30 · 7 s | 0/30 · tool list alone is 1054 tokens > 1024 |
| focus, 10 tools, 20 cases | 12/20 · 1.4 s | 12/20 · 7.1 s | (8/10 EN, run cut short — rerun pending) |

Reached = every expected call made, in order, with matching arguments;
extras allowed except on no-op cases. Median per case.

| model | location | search | maps | photo OCR | translate | speak | no-op |
|---|---|---|---|---|---|---|---|
| Apple FM (on-device) | ✓ | ✓ | ✓ | ✓ | ✓* | ✓ | 0/2 |
| LFM2.5-1.2B-Instruct_int4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | 2/2 |
| LFM2.5-1.2B_int4_gpu (on CPU) | ✓ | ✓ | ✓ | ✗ | — | ✗ | — |
| LFM2.5-2.6B_int4 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (EN; JA missed) | 0/2 |

\* one FoundationModels-internal error on the EN translate case.

## Per model

**Apple FM** — reached 17/20 (exact 6). Routes everything, and chains on
its own: "find a cafe" becomes get_location → search_places("cafe near
Chuo, Osaka") → open_in_maps("CAFE LA") — better than the expected single
call. The cost of that eagerness: both no-op cases grabbed a tool
(speak_out_loud for "What is 2 plus 2?", translate for the JP one).
Median 3 s per case.

**1.2B-Instruct** — reached 15/20 (exact 15). Never chains (multi-tool
cases stop after the first call) and never routes speak — "I'm sorry, but I
can't read text aloud", exactly the demo behavior. But it is the only model
that passed both no-op cases: it does not grab tools for unrelated
questions. Median 4.4 s per case.

**2.6B** — reached 17/20 (exact 14). Routes everything and chains
multi-tool cases correctly in both languages (search → maps). Over-triggers
like Apple FM: translate on both no-op cases, an unasked OCR call after
EN searches, and the JA speak case wandered to OCR. Median 15.5 s per
case — 3.5× the 1.2B, 5× Apple FM. (A first attempt at this run hit a
mid-generation engine hang; the rerun completed clean.)

## Photo-editing pack: 15 tools, and an upset

| model | reached | exact | no-op restraint | median/case |
|---|---|---|---|---|
| Apple FM | 14/20 | 13 | 0/2 | 2.7 s |
| LFM2.5-1.2B-Instruct_int4 | **16/20** | **16** | 2/2 | 7.2 s |
| LFM2.5-2.6B_int4 | 2/20 | 2 | (2/2)* | 13.5 s |

The 1.2B beats Apple FM on this pack — the first measured counterexample
to "Apple FM wins outright". How each model loses is the story:

- **Apple FM**: told "make it feel warmer", it chose the right tool and
  passed `amount: -100` — maximum *cooling*. A sign error the routing
  metric alone would have called a pass. In Japanese it stops trusting
  itself with vague amounts: 「もう少し明るくして」 gets a counter-question
  ("how much, -100 to 100?") instead of a call — three cases lost that
  way. And it still grabs a tool on both no-op cases.
- **1.2B**: discriminates all fifteen tools in English — including the
  warmth sign Apple FM got wrong — but cannot chain (it mashed two calls
  into one JSON argument), and in Japanese the enum-argument tools break:
  「右に90度回転して」 is refused in English, quoting its own enum
  ("the available rotation options are 90, 180, or 270 degrees").
- **2.6B: total collapse, and not about routing.** Its 1.55 GB of weights
  cap the context at 1024 tokens on this phone; the 15-tool list eats
  nearly all of it, generation dies mid-thought ("I need to use the"),
  and the only passes are the two no-op cases — correct by paralysis*.
  The same model scored 17/20 on the 6-tool pack. On phone RAM, a bigger
  model buys a smaller context: past some tool-list size the smaller
  model is simply the stronger agent.

## Photo-editing at 17 tools: the going-back triangle

The demo grew the pack to 17 tools (remove_background, revert_to_original
alongside undo_photo_edit) and the recording had already shown that
"undo everything" falls into undo on the 1.2B. Ten cases were added to
measure the triangle in both languages — undo the last edit, undo
everything, reset it, remove the background, cut out the person — for 30.

| model | reached | exact | no-op restraint | median/case |
|---|---|---|---|---|
| Apple FM | **24/30** | 24 | 1/2 | 1.8 s |
| LFM2.5-1.2B-Instruct_int4 | 17/30 | 17 | 2/2 | 7.0 s |
| LFM2.5-2.6B_int4 | 0/30 | 0 | — | 2 ms (rejected before generating) |

- **Apple FM owns the triangle.** All ten new cases pass in both
  languages: "Undo the last edit" → undo_photo_edit, "Undo everything /
  Reset it" → revert_to_original, "Cut out the person" →
  remove_background — the discrimination the 1.2B needed a tool-set cut
  for, it does by name. Five of its six losses are a *magnitude*:
  "more contrast", "warmer", 「もう少し明るくして」 all arrive as
  `amount: 100`, the rail. (On the 15-tool run the same Japanese wordings
  drew a counter-question instead; vague-amount handling is not stable
  run to run.) The sixth: the Japanese no-op grabbed undo_photo_edit.
- **1.2B: the same 20 as before, plus one.** On the original twenty it
  reaches 16, exactly as before; the two extra tools cost nothing there.
  On the ten new cases it reaches 1: "Undo everything" and "Reset it" both
  fall into undo_photo_edit (the well, measured on the bench now, not
  just the stage), "Undo the last edit" is *refused* — "I can't undo the
  last edit, my capabilities are limited to applying edits" — with
  undo_photo_edit in the list, and every Japanese wording of the
  triangle is refused with a recital of the tools it thinks it has. The
  stage cut (no one-step undo) remains the right recording set; the
  bench keeps the full set because the well is the measurement.
- **2.6B: the list no longer fits.** With 15 tools the prompt fitted the
  1024-token context and generation died mid-thought; with 17 the tool
  list plus instructions is 1054 tokens and every case is rejected in
  2 ms ("Input token ids are too long"). The cliff has a number now.

## Focus pack: 10 tools, and a draw

"Help me focus" as timer + notifications + brightness + notes; the axes
are the `set_` prefix neighbours, get/set brightness, remind-vs-remember
(schedule_notification vs write_note) and one two-call chain written in
call order. Apple FM and the 1.2B both reach 12/20 — by losing
completely different cases.

| model | reached | exact | chains (2) | no-op restraint | median/case |
|---|---|---|---|---|---|
| Apple FM | 12/20 | 12 | 2/2 called, 0/2 right amount | 1/2 | 1.4 s |
| LFM2.5-1.2B-Instruct_int4 | 12/20 | 12 | 0/2 | 0/2 | 7.1 s |
| LFM2.5-2.6B_int4 | 8/10 EN before the run was cut short | | 0/1 | 0/1 | 22 s |

- **Apple FM: right tool, wrong number.** "Set a timer for 25 minutes"
  → asks "what should the timer be for?" (the required `label` becomes
  a question); 「25分」 → `seconds: 150`; "one-hour focus timer" →
  `seconds: 600` in both languages. Minutes-to-seconds is a failure
  mode of its own. "Remind me to stretch in half an hour" → set_timer
  with the right 1800 s — the timer absorbs "remind me in N" — and the
  EN no-op ("how long should a pomodoro break be?") became a 25-second
  timer. 「画面を暗くして」 → 50 %, which the case scores as not dim.
  Chains are called in order every time.
- **1.2B: right number, wrong tool.** The mashed chain
  `cancel_notifications({"set_timer(label":"Focus","seconds":3600})`
  carries the correct 3600 s inside a broken call; "25 minutes" →
  15000 s (Japanese 「25分」 correct). remind-vs-remember holds up —
  schedule_notification and write_note both route in both languages —
  but *read* notes does not: "What did I ask you to remember?" →
  write_note both times. And this is the first pack where it loses its
  no-op restraint: both pomodoro questions became timers. The Japanese
  reminder call dropped a required `title` and errored at the tool.
- **2.6B, partial:** 8/10 on the English half at 22 s per case (10
  tools fit its 1024-token context with room to generate) — the chain
  stopped after cancel_notifications, the no-op grabbed a timer — then
  the app was sent to the background mid-run (see harness notes) and the
  Japanese half never ran.

## Corrected: the 1.2B translate "floor"

The demo concluded the 1.2B never routes translate — five rewrites of
prompt, description and tool name changed nothing. The bench shows it
routes translate cleanly in both languages when the text is quoted in the
request (`{"source":"good morning","to":"ja"}`). The demo beat said
"Translate **that**" — the failure was never tool selection, it was
resolving a reference to the previous answer into a tool argument. The
floor is anaphora, not routing.

Speak stays a real floor: fresh session, quoted text, either language —
the 1.2B still answers "I can't" instead of calling the tool.

## What moves routing

- The tool name is the strongest signal — stronger than the description or
  the system prompt.
- Negative system-prompt lines poison the 1.2B: "you cannot X" becomes its
  excuse to refuse, and the refusal outlives the sentence's removal.
- The bare tool list (LFM2's trained format, no OpenAI function envelope)
  cut the same six tools from 376 to 253 tokens.
- Phrasing sensitivity is real on the 1.2B: 「ここは何という街?」was
  treated as a translation request and answered without any call.

## Harness notes (learned the hard way)

- Canned tool results must cohere with the request: Apple FM saw
  "(translated text)" come back from the recording translate tool and
  retried the call twice.
- A LiteRT engine hang mid-generation blocks the transcript reader too —
  the runner writes case-start lines and aborts the model's run on a 180 s
  timeout instead of touching the transcript. That timeout was dead code
  until the evening: a `withThrowingTaskGroup` race awaits *every* child
  before it returns, even after the timer child throws, and a child
  awaiting a detached `respond` never finishes — the bench sat five
  minutes past its own deadline. The deadline is now a continuation the
  timer resumes directly; the hung work stays hung on its own thread.
- **The "hangs" were the app leaving the foreground.** Three runs froze
  ~20 s in with no error line; the fourth, with a
  `didEnterBackground` observer writing to the JSONL, showed
  `{"type":"background"}` at the exact case the silence began. A
  backgrounded app generates nothing and its timers stop with it, so
  no timeout can save it. The runner now keeps the screen awake
  (`isIdleTimerDisabled`), and the rule for a run is: nobody touches
  the phone.
- zsh ties `path` to `PATH`; a `read -r _ path` loop over an empty
  stream sets `PATH=""` and the next `tee` is "command not found". The
  orchestrating scripts avoid the name.
- One hung `devicectl` launch started the app *without its arguments*, and
  the no-`--model` fallback silently ran the newest bundle. Every run's
  JSONL records the model the process actually loaded; the script verifies
  it against what was asked.

## Numbers

LFM2.5-1.2B-Instruct_int4, CPU, cold: TTFT 1.02 s, prefill 256 tok/s,
decode 46 tok/s. Thermals are visible run to run: prefill drops to
~180 tok/s across back-to-back runs.

## Measurement asymmetry

Apple Foundation Models runs out of process; its memory use cannot be
measured from inside the app. Memory numbers, where they appear, cover the
LiteRT path only (`phys_footprint`).
