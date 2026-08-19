# Inbox — mail triage, said out loud

The Spark type: fifteen canned messages, none real (three newsletters, an
invoice, a question from a colleague, a notice from the property
company). list / search select; archive / snooze / flag / mark-read act
on the selection; `draft_reply` writes from a gist and never sends.
"Archive the newsletters" is the chain the pack is for: find them, then
act on what was found. Tools: `ToolBox.inbox`, 9
(`Tools/InboxTools.swift`). Launch:
`--autorun --backend apple --scenario inbox`.

| beat | say | expect |
|---|---|---|
| 1 | What's new in my inbox? | `list_inbox(unread)` — 7 rows, the panel fills |
| 2 | Archive all the newsletters. | `list_inbox(newsletters)` → `archive_selection` — find-then-act |
| 3 | Snooze the invoice from Kanda Goods until tomorrow. | `search_mail(Kanda)` → `snooze_selection(tomorrow)` |
| 4 | Flag the one from the property company. | `search_mail(…)` → `flag_selection` |
| 5 | Reply to Hana: I'll send the report by Friday. | `draft_reply(1, …)` — a draft on screen, nothing sent |
| 6 | Archive everything I've already read. | `list_inbox(read)` → `archive_selection` |

日本語版: 新着メールは?→ ニュースレターを全部アーカイブして。→ Kanda Goods の請求書を明日までスヌーズして。→ 大家さんからのにフラグを付けて。→ Hana さんに返信して:金曜までにレポートを送ります。→ 既読のメールを全部アーカイブして。

Design: the actions are selection-wide on purpose — triage is bulk work —
and every action clears the selection so a stale "them" cannot hit the
wrong rows; message numbers come from the state; snooze times are an
enum (tonight / tomorrow / next_week). Nothing here touches a real
account: the pack is a stand-in for the category, all data canned.
Cases: 14 EN + 14 JA — three find-then-act chains, a no-call case (the
unread count is in the state) and an ask-back ("Snooze it." — which
one?).

Routing: **23/34 on Apple FM via the Mac lane** (2026-08-19 evening, up
from 15 that morning). What moved it was all structure: the state line
stopped teaching find-first ("number tools act straight on the numbers
above"), every number argument's guide says the same, the finder fakes
echo the real rows, and delete's false branch no longer commands the
confirm-true call (the model had been answering its own confirmation
with it). The number-tool family (read, reply, unsubscribe, delete) went
direct in both languages and both no-call cases pass. The residue reads
as the model's, not the pack's: a search still slips in before Japanese
unsubscribes and chains, "Snooze it." snoozes instead of asking, and
「今のを取り消して」 deletes instead of undoing even with "Last change:"
named in the state.
