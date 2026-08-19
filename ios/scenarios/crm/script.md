# CRM — a Salesforce's pipeline, said out loud

The first business-wing pack (docs/business-packs.md): one sales team's
quarter, frozen — 8 opportunities across 6 companies and 3 owners, 6
contacts, 2 open tasks, and a calendar that never moves (the state pins
`Today: 2026-08-20`, so "this month" and "tomorrow" are absolute dates a
case can score). Finders make the selection; every action takes its
record as an id argument — no bulk tools, no confirm gate (nothing here
is destructive; the rails are ask_user and undo_last). Tools:
`ToolBox.crm`, 12 (`Tools/CRMTools.swift`). Launch:
`--autorun --backend apple --scenario crm`.

| beat | say | expect |
|---|---|---|
| 1 | Which deals close this month at a million yen or more? | `search_opportunities(min_amount: 1000000, close_date_to: 2026-08-31)` — O1 + O5 |
| 2 | Mark the Aozora one as won, and set a follow-up task for tomorrow. | `update_opportunity_stage(O1, won)` + `create_follow_up_task(due 2026-08-21)` — "the Aozora one" is beat 1's selection, and the row's stage flips on screen |
| 3 | Show me Tanaka's deals. | `search_opportunities(owner: Tanaka)` — 3 rows |
| 4 | Raise O3 to 1,000,000 yen. | `update_opportunity_amount(O3, 1000000)` — the similar-tool triple, leg 2 |
| 5 | Reassign O7 to Suzuki. | `assign_opportunity(O7, Suzuki)` — leg 3 |
| 6 | Add a note to O4: budget approved in October. | `add_note(O4, …)` |

日本語版: 今月中にクローズ予定で100万円以上の案件は?→ アオゾラの方を受注にして、明日フォローアップを入れて。→ 田中さんの案件を見せて。→ O3を100万円にして。→ O7を鈴木さんの担当にして。→ O4にメモを付けて: 10月に予算承認の見込み。

Design: the state carries counts and handles (owners, companies, the
frozen today), never full rows — listing every deal would let search
questions be answered from the state and the finders are what the pack
measures; selection rows carry every handle a person points with (id,
company, amount, stage, owner, close date — the shopping pack's
brand-line lesson). Actions take ids straight from the request or the
selection (the video pack's target-argument lesson), so there is no
find-then-act chain to lose. `update_opportunity_stage` vs
`update_opportunity_amount` vs `assign_opportunity` is a deliberate
similar-tool triple, instrumented by cases. Kana→romaji normalization
in every finder (the money pack's Maruetsu lesson): 田中・アオゾラ・
ホシノ電機 all find their canned rows. Cases: 18 EN + 18 JA — the
search axes (amount+date, owner, company, stage), the triple, entity
resolution through the selection, the frozen-today date arithmetic
(明日 → 2026-08-21), a no-call case and an ask-back
("Update the stage." — which deal, to what?).

Routing: **20/36 on Apple FM via the Mac lane** (2026-08-20, four
one-variable rounds: neutral fakes 15 → dynamic echoes 20 (the
committed config) → two wording rounds against the get-prefix, 18 and
20, both reverted). The stable remainder, all instrument findings:
get_opportunity prefixed to id-acting calls in both languages (the
look-first recipe), 受注にして → assign_opportunity with the current
owner, 100万円以上 split into min 100,000 + max 1,000,000 (the 万
lesson in the units recipe), "mark it closed" → stage lost, and
「今月中」/"this month" never getting its close_date_to bound.
