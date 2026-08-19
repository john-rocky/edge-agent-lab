# Shopping — the buyer's side of the counter, said out loud

The Amazon type: not an admin operating records (that is the store pack),
a customer finding and buying. Search → sort → "the second one" → cart →
coupon → checkout, over a 20-item canned catalog (prices in yen). The
state names the numbered results and the cart with its total, so "add the
second one" is a number the model reads, and every sum is the app's —
the model never does arithmetic. Tools: `ToolBox.shopping`, 9
(`Tools/ShoppingTools.swift`). Launch:
`--autorun --backend apple --scenario shopping`; chat: `--scenario
shopping` without `--autorun`.

| beat | say | expect |
|---|---|---|
| 1 | Find wireless earbuds. | `search_catalog` — 5 numbered results, the panel fills |
| 2 | Sort them by price, cheapest first. | `sort_results(price_low)` — the numbers reshuffle |
| 3 | Add the second one to the cart — two of them. | `add_to_cart(number: 2, quantity: 2)` — the state test |
| 4 | Actually, make it just one. | `change_quantity(…, 1)` — the cart line by name |
| 5 | Use the coupon SAVE10. | `apply_coupon(SAVE10)` — the total drops 10% |
| 6 | Check out. | `checkout` — order placed, cart clears |

日本語版: ワイヤレスイヤホンを探して。→ 安い順に並べて。→ 2番目のをカートに2つ入れて。→ やっぱり1つにして。→ クーポン SAVE10 を使って。→ 注文を確定して。

Design: results are numbered in the state and the tools take those
numbers (`add_to_cart(number:)`); cart lines are addressed by name
(`change_quantity(item:)`) because that is how the person says it; the
coupon table is canned (`SAVE10` −10%, `HELLO5` −5%); `track_order`
answers for order #5230, already on its way. Cases: 14 EN + 14 JA — the
number-from-state axis, a search→add chain, a no-call case (the total is
in the state) and an ask-back ("Add it to the cart." — add what?).

Routing: **23/34 on Apple FM via the Mac lane** (2026-08-19; up from
13/28 before "the results in the state are live" replaced "search
before adding" — the model had obeyed that line literally on every add).
