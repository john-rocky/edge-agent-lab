# Business packs — the benchmark's office wing (spec, 2026-08-20)

What this OSS ultimately answers: **"can this on-device model be trusted
to call this kind and this many of a real app's features?"** — judged on
the phone, not on a leaderboard. Raw speed is not the question. The
questions are: does the model pick the right tool, fill the right
arguments, order a multi-call correctly, survive a growing tool list,
tell similar tools apart, and do all of it in Japanese as well as
English — per model, and per tool-definition wording. Behind all of
them sits the bench's central research question: **how many tool
specs, under what names, with what descriptions, does a small LM stay
stable with** — the packs are the corpus, the evaluation program below
is the instrument, and the answer is the envelope this OSS exists to
publish.

The division of labor stays what every recipe here assumes: the model
turns a short utterance (or an image) into **one of a finite set of
tools plus structured arguments** — nothing more. Log analysis,
long-horizon planning and general agent loops are out of scope.

```
user request → on-device LM → tool selection → argument generation
             → tool call → ordinary code executes it
```

## Three families

| family | packs | status |
|---|---|---|
| **Creative** | image editing, video editing, VLM→tools (vision/polish) | built |
| **Native** | iOS frameworks and APIs (audio, docs, sensors, …) | built |
| **Business** | CRM, Commerce/POS, Project Management, ERP/Accounting, HCM, Collaboration | this spec |

Creative and Native reuse what exists. The growth axis from here is
**Business** — the tool sets of the software the world's offices already
run (Salesforce, Shopify, SAP, Jira, Workday, Slack), reproduced as
tools over frozen local fixtures. No real backend, no external API, no
DB: the benchmark calls mock tools, and that is enough, because what is
being measured is the model's side of the contract.

Two of the six are already part-built under other names: the **store
pack is the Commerce pack's admin half** (18 tools, 44 cases, measured)
and the **money pack covers the expense corner of ERP/Accounting**. The
spec below extends rather than replaces them.

## Sample apps are first-class

Every business category gets a **minimal sample app** — not to imitate
the real product, but so the value of tool calling is visible on a
screen (user decision 2026-08-20: integration stays mock, but each
category must be seeable):

- a few rows of fixture data on screen,
- a natural-language input field,
- the tool call the model produced, shown verbatim,
- the mock tool executes, **the visible data changes**,
- expected vs. actual call inspectable (debug panel).

Common layout: input on top, mock app UI in the middle, debug panel
(Selected Tool / Arguments / Result, plus Expected vs Actual where a
case is loaded) at the bottom. No login, no auth, no server, no cloud
DB, no real-service APIs, no push, no deep navigation, no
production-grade UI, no complex business logic. Fixtures may reset on
relaunch.

**Benchmark and sample app share one tool implementation** — this is
already the repo's architecture (the same `Tool` structs drive the
stage and, wrapped in `RecordingTool`, the bench) and it stays the law:
a pack is one directory of tool definitions + fixtures + cases + a
sample UI, never two implementations.

## Pack specs

Tool names below are normalized to this repo's convention (snake_case,
named for the verb the user will say — see recipes). Every pack carries
the three standing rails: `ask_user`, `undo_last`, and the `confirm`
argument on destructive tools.

### CRM (Salesforce / HubSpot) — P0, ~10 tools

Entities: contacts, companies, opportunities, tasks.

Tools: `search_contacts(name?, company?, email?)`,
`get_contact(id)`, `search_companies(name?, industry?, location?)`,
`search_opportunities(company?, owner?, stage?, min_amount?,
max_amount?, close_date_from?, close_date_to?)`,
`get_opportunity(id)`, `update_opportunity_stage(id, stage)`,
`update_opportunity_amount(id, amount)`, `assign_opportunity(id,
owner)`, `create_follow_up_task(contact?, opportunity?, title,
due_date)`, `add_note(entity_id, text)`.

Sample app: 5–10 opportunities (company, amount, stage, owner, close
date). Beats: 「今月クローズ予定で100万円以上の案件」→
`search_opportunities(min_amount: 1000000, close_date_from/to: …)`;
「この案件を受注にして」→ `update_opportunity_stage(…, "won")` and the
row's stage flips Proposal → Won on screen; multi-tool
「この案件を受注にして明日フォローアップを入れて」→ stage update +
`create_follow_up_task`.

### Commerce / POS (Shopify / Square) — P0, ~15 tools

The store pack, extended. Existing: product search/filter, order
filters, price and status updates, inventory, fulfil, refund (with the
confirm gate), payment reminders. The spec adds: `get_product`,
`adjust_product_price(amount? | percentage?)` as the *relative* price
change beside the absolute one (a deliberate similar-tool pair),
`cancel_order` (destructive, beside fulfil and refund — a deliberate
status-verb triangle), `search_customers(name?, email?,
total_spent_above?)`, `create_discount(percentage? | amount?,
products?, expires_at?)`.

Sample app: Products + Orders, two tabs. Beats: 「在庫5個以下の商品」;
「この商品を10%値下げ」 → `adjust_product_price(…, percentage: -10)`
and ¥5,000 → ¥4,500 on screen; 「昨日の未発送注文」; 「この注文を
発送済みにして」 → Unfulfilled → Fulfilled.

### Project Management (Jira / Asana / Linear) — P0, ~10 tools

Entities: issues, projects, assignees, statuses, priorities.

Tools: `search_issues(project?, status?, priority?, assignee?,
creator?, keyword?, due_date_from?, due_date_to?)`, `get_issue(id)`,
`create_issue(project, title, description?, priority?, assignee?)`,
`assign_issue(id, assignee)`, `change_issue_status(id, status)`,
`change_issue_priority(id, priority)`, `change_due_date(id, due_date)`,
`add_comment(id, text)`, `close_issue(id)`.

Sample app: one issue list (id, title, status, priority, assignee).
Beats: 「iOSの未着手P1バグ」→ `search_issues(project: "iOS", status:
"todo", priority: "P1")`; 「APP-123を田中さん担当にして進行中にして」→
`assign_issue` + `change_issue_status`, both columns change at once.
Chosen for P0 because its tool list is dense with deliberate
similar-tool pairs (four `change_*`, close-vs-status).

### ERP / Accounting (SAP / NetSuite / QuickBooks) — P1, ~11 tools

Entities: orders, invoices, expenses, inventory. Tools:
`search_orders`, `get_order`, `update_order_status`,
`search_invoices(customer?, payment_status?, due_date_from/to?,
min_amount?)`, `get_invoice`, `create_invoice(customer, items,
due_date)`, `mark_invoice_paid(id)`, `search_expenses(category?,
employee?, dates?, amounts?)`, `update_expense_category(id, category)`,
`search_inventory(product?, sku?, location?, quantity_below?)`,
`adjust_inventory(sku, location, delta)`.

Sample app: Invoices + Inventory, two tabs. Beats: 「今月期限の未払い
請求書」; 「これを支払い済みにして」 → Unpaid → Paid; 「大阪倉庫で
在庫10個以下の商品」; 「この商品の在庫を5個増やして」.

### HCM / HR (Workday) — P1, ~9 tools

Entities: employees, leave requests, shifts. Tools:
`search_employees(name?, department?, office?, manager?, status?)`,
`get_employee`, `search_leave_requests(employee?, status?, dates?)`,
`create_leave_request`, `approve_leave_request(id)`,
`reject_leave_request(id)`, `search_shifts`, `assign_shift`,
`update_shift(id, start?, end?)`.

Sample app: Employees + Leave Requests. Beats: 「大阪オフィスの営業部」;
「田中さんの有給申請を承認して」 → find-then-act chain, Pending →
Approved.

### Collaboration (Slack / Teams) — P2, ~8 tools

Entities: channels, messages, threads. Tools:
`search_messages(keyword?, channel?, sender?, dates?)`, `get_thread`,
`send_message(channel, text)`, `reply_to_thread(id, text)`,
`create_channel(name)`, `invite_to_channel(channel, users)`,
`mute_channel(channel)`, `add_reaction(id, reaction)`. The inbox pack
already measures the mail half of triage; this pack is lower priority.

## Tool taxonomy and properties

Every business tool falls into one of five categories — **Search**
(language → query conditions), **Read** (fetch one entity), **Create**,
**Update**, **Action** (a business state transition: fulfil, approve,
close) — and carries one property: `read`, `write`, or `destructive`.
The first benchmark generation scores selection and arguments;
permission UI built on the property is app-side and out of the OSS's
core (the confirm gate already covers the destructive class).

## Common case categories

Each pack's cases cover the same axes (most are already measured on the
seven built packs; recipes cross-referenced):

- **Single tool**, **multiple arguments** (在庫5個以下 / 大阪倉庫で…)
- **Similar tools** — deliberately planted pairs
  (update_product_price vs adjust_product_price; update_order_status vs
  fulfill_order vs cancel_order). The gravity-well recipe says every
  addition moves the wells; these cases are the instrument.
- **Multi-tool** in stated order.
- **Entity resolution** — 「田中さんの案件」「Acmeの注文」; "this
  one" resolves through the selection state, per the state-line recipes.
- **Relative dates** — 昨日 / 今週 / 来月 / 金曜日 / 月末. The pack's
  state line pins a frozen "today" (the fixtures are a frozen world), so
  expected arguments stay deterministic and the date matcher can be
  exact.
- **Numeric constraints** — 100万円以上, 10個以下, 10%値下げ, 500円
  上げる (signed-range and units recipes apply).
- **Paraphrase** — the same intent in several wordings (受注にして /
  Wonにして / 成約扱いにして / この商談決まったことにして).
- **No-op / unsupported** — a request the pack cannot serve calls
  nothing (or `ask_user`), never a plausible tool.

## The evaluation program

1. **Tool-count scaling.** Run the same cases at 5 / 10 / 20 / 35
   tools, later 50–70 with more packs — selection accuracy, argument
   accuracy, similar-tool confusion, multi-tool accuracy, latency,
   context use. The ceiling is known to be memory × count, not count
   (the 2.6B died at a 1054-token tool list); business packs give the
   curve its business shape.
2. **Realistic in-app mixes.** A real commerce app exposes products +
   orders + customers + inventory + discounts at once; measure entity
   discrimination inside one domain.
3. **Cross-domain.** CRM + Commerce + PM in one list (50–100 tools):
   「昨日の未発送注文」 must route to commerce's order search, 「田中
   さん担当のP1バグ」 to PM's issue search, 「今月クローズ予定の商談」
   to CRM. Note: the domains collide on names (`search_orders`,
   `search_inventory` exist in two packs) — merging forces either
   prefixes or entity-distinct names, and either choice re-routes old
   sentences; measure, don't assume.
4. **Definition optimization.** Same tool, A/B on name / description /
   parameter names / enums / schema, same case set (the noise-floor
   recipe: expect structure to move scores and wording to drown; the
   loop *definitions → bench → failures → change → re-test* is the
   long-term automation target).
5. **Failure records.** Every failure keeps: input, expected/actual
   tool, expected/actual arguments, available tools, definitions,
   model, latency, language, pack. The bench JSONL already carries most
   of this (input, expected, calls, selectionPass/argsPass, model, ms,
   lang); add the tool-list identity so cross-config analysis works.
6. **Metrics.** Tool selection / argument / multi-tool / order / no-op
   / similar-tool / entity-resolution / domain-selection accuracy,
   per-language accuracy, latency, peak memory (LiteRT path only —
   Apple FM runs out of process and cannot be measured from the app).

## Layout

The repo's existing pack layout already realizes the spec's structure —
one place per pack for tools, fixtures, cases and UI:

```
lfm-tools-ios/Sources/Tools/<Pack>Tools.swift   tool definitions + fixtures (frozen)
edge-agent-lab/ios/scenarios/<pack>/cases.json  bench cases (state + expected)
edge-agent-lab/ios/scenarios/<pack>/script.md   demo script
lfm-tools-ios app                               the sample UI (state panel + debug)
```

New business packs follow it; fixtures may live as JSON where that is
simpler than Swift literals.

## First implementation scope

CRM (~10 tools) + Commerce (store extension to ~15) + Project
Management (~10): ~35 tools, evaluated at 5/10/20/35. Then ERP,
HCM, Collaboration toward 50–70. Sample-app order: Commerce first
(search, numeric change, status change, multi-tool — all visible),
then CRM, then PM.

## What the OSS is for

Not "how to call tools with Foundation Models" — that is easy. The
value: tool sets modeled on the real app market, cases shaped like real
app requests, multiple on-device models compared, performance under
tool-count growth, similar-tool confusion measured, definition changes
evaluated, regressions caught, and sample apps where the whole loop is
visible on screen.
