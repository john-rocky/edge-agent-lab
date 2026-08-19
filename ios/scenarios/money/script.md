# Money — a household-budget app, said out loud

The Money Forward type: the records are the user's spending. A month of
canned transactions (30 rows, yen; two subscriptions recur, five rows are
uncategorized, eating out is over budget — so every report has something
to say). Finders select (a period, a category, a payee, the
uncategorized); categorize / flag act on the selection; the reports fold
the rows into an answer with the arithmetic done by the app. Tools:
`ToolBox.money`, 9 (`Tools/MoneyTools.swift`). Launch:
`--autorun --backend apple --scenario money`.

| beat | say | expect |
|---|---|---|
| 1 | What did I spend this week? | `spending_report(7)` — total + by category |
| 2 | Show me the uncategorized ones. | `filter_by_category(uncategorized)` — 5 rows selected |
| 3 | They're all groceries — categorize them. | `categorize_selection(groceries)` — the anaphora beat: "they" is beat 2's selection |
| 4 | Find my subscriptions. | `find_subscriptions` — Netflix + Spotify, the app's heuristic |
| 5 | Set the eating-out budget to 25,000 yen. | `set_budget(eating_out, 25000)` |
| 6 | How am I doing against my budgets this month? | `budget_report` — eating out over, the rest under |

日本語版: 今週いくら使った?→ 未分類のを見せて。→ 全部コンビニとかだから食料品に分類して。→ サブスクを洗い出して。→ 外食の予算を25,000円にして。→ 今月、予算に対してどう?

Design: a subscription is a payee recurring on a near-identical amount —
the app's heuristic, never the model's; `filter_by_category` accepts
`uncategorized` as a value because triage is the job; budgets and
categories are enums so the rails hold. Cases: 14 EN + 14 JA — the
filter→categorize chain, report days as numbers, a no-call case (the
month total is in the state) and an ask-back ("Set a budget." — which,
to what?).

Routing: **22/30 on Apple FM via the Mac lane** (2026-08-19 evening, with
the finder fakes echoing real arguments and a kana→romaji step in
search_payee — 「マルエツ」 now finds the Maruetsu rows instead of
routing perfectly into an empty answer). The categorize-or-flag piled
onto a finder persists with rich results in both languages — the
eagerness trait, still open.
