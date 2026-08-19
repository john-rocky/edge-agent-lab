# Store — a Shopify admin's menu, said out loud

The second market-in pack, and a different kind of agent from every pack
before it. The photo and video packs shortcut an editor's UI; this one
operates records: natural language → search / filter → update the rows
found → a business step (fulfil, remind, refund, report). The data is
canned — 24 products, 20 orders of a small goods shop, in yen — so the
inputs are tiny and a local model is in reach, and the bench gets a second
class of case: was the *query* right, not was the edit right. Tools:
`ToolBox.store`, 14 (`Tools/StoreTools.swift`). Launch:
`--autorun --backend apple --scenario store`; `--voice` for spoken beats.

The shape is the admin's own: a search or filter makes a **selection** (the
admin's checked rows), and the bulk actions — reprice, tag, change status,
restock, fulfil, send reminders — act on that selection. "Cut their prices
by 10%" carries no ids: *their* is the selection beat 1 made, resolved by
the app. The state line at the top of every message says what is selected
and how it was found; the tools take the numbers the words name.

Not yet run — the phone was in use. Written so the first run answers it:
`run.log` carries per beat `STATE` (the block the model read) and `TOOL`
(what it called and what came back).

| beat | say | expect |
|---|---|---|
| 1 | Which products have fewer than 5 in stock? | `find_low_stock(below: 5)` — 6 rows, a table on screen; they are now the selection |
| 2 | Cut their prices by 10%. | `update_price(percent_change: -10)` on the selection — not `set_price`; the prices in the table drop |
| 3 | Tag them 'clearance'. | `add_tag(clearance)` on the same selection |
| 4 | Show me the orders that haven't been paid. | `filter_orders(pending, any)` — 5 rows; the selection is now orders |
| 5 | Send them a payment reminder. | `send_payment_reminder` on the selection |
| 6 | Fulfil all the paid orders that haven't shipped yet. | `filter_orders(paid, unfulfilled)` → `fulfill_orders` — a two-call chain; 5 orders flip to fulfilled |
| 7 | How were sales this week? | `sales_summary(days: 7)` — orders, yen, vs the week before, top items |

日本語版(未実測):

| beat | 言う |
|---|---|
| 1 | 在庫が5個未満の商品はどれ? |
| 2 | その商品の価格を10%下げて。 |
| 3 | 「clearance」のタグを付けて。 |
| 4 | 未払いの注文を見せて。 |
| 5 | 支払いのリマインダーを送って。 |
| 6 | 支払い済みで未発送の注文を全部発送済みにして。 |
| 7 | 今週の売上はどうだった? |

What the model reads (ahead of the words, every beat):

    [App state] Store: 24 products (18 active, 4 draft, 2 archived), 20
    orders (10 unfulfilled, 5 awaiting payment). Selection: none — search or
    filter first, then act.

    Which products have fewer than 5 in stock?

After beat 1: `Selection: 6 products from stock below 5: Wool Beanie
(¥3,200, stock 0); Straw Hat (¥4,600, stock 1); Wide Chinos (¥8,900,
stock 2); Linen Shirt (¥6,800, stock 3); Wool Scarf (¥5,400, stock 4);
Field Jacket (¥16,500, stock 4).` — so beat 2's "their" has a referent the
model can see, and the answer to "how many are waiting for payment?" is in
the message with no tool at all.

Design

- **Selection is the app's.** Every finder (`search_products`,
  `filter_products`, `find_low_stock`, `filter_orders`) replaces the
  selection; every action reads it. An action with nothing selected
  returns "search or filter first, then act" — the model's cue to chain.
  Anaphora ("their", "them") is resolved by the app, the recipe again.
- **Discrimination axes**, on purpose: `update_price(percent_change)` vs
  `set_price(price)` — "cut 10%" vs "set to 3,000 yen"; `search_products`
  (by name only) vs `filter_products(by: status|vendor|tag|product_type)`
  vs `find_low_stock` — which finder; `fulfill_orders` vs
  `send_payment_reminder` — ship vs chase; `filter_orders` takes two enums
  with `any`, so "unpaid" is payment=pending and the fulfilment axis is
  left alone. Search matches names only: a search that also matched
  vendors made "everything from Hokkaido Wool" a coin toss between two
  tools, and a bench cannot score a coin toss.
- **Signed ranges made unmistakable** (recipe): the percent guide reads
  "-10 lowers prices by 10%, 15 raises them by 15%".
- **The data.** `StoreData` in `StoreTools.swift`: 24 products (vendor,
  type, tags, price, stock, status: 18 active / 4 draft / 2 archived; six
  under 5 in stock), 20 orders (5 awaiting payment, 5 paid-and-unfulfilled,
  1 partial; days count back from today so `sales_summary(7)` means the
  same thing on any date: 13 orders, ¥104,500, up 44% on the week
  before). Prices reprice to the nearest ¥10.
- **On screen**: every finder and bulk action posts a table
  (`Artifact.table`) — the selection as an admin's list, up to eight rows.
  There is no persistent panel yet; the card under the answer is the
  view.

Bench: 17 EN + 17 JA in `cases.json`, each with the `state` block it is
scored against (nothing selected / the six low-stock products / the five
unpaid orders). Run with `SCENARIO=store ./run-device.sh` (toolset
`store`, canned results in `BenchToolBox.store`).

When the phone is back (what to read in `run.log`)

- Beat 2 must be `update_price`, not `set_price`; its argument must be
  negative (the signed-range guide's test).
- Beat 3's tag must land on the six low-stock rows, not on a fresh search
  — the `TOOL` line lists the products it touched.
- Beat 6 must be two calls in one beat; the second must not fire before
  the first returned (the log's order).
- Beat 7 is the one report beat: `sales_summary(7)`, no records change.
