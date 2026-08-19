# PM — a Jira board, said out loud

The second business-wing pack (docs/business-packs.md), chosen for P0
because the tool list is dense with deliberate similar tools: four
change_* verbs (assign / status / priority / due date) that differ only
in which column they touch, plus close_issue beside
change_issue_status. One team's sprint, frozen — 12 issues across 3
projects and 3 assignees (one issue unassigned, exactly one iOS P1
untouched), and a calendar that never moves (`Today: 2026-08-20`, a
Thursday: "Friday" is 08-21, "next Monday" 08-24). search_issues makes
the selection; every action takes its issue as an id argument. No
destructive tool, no confirm; the rails are ask_user and undo_last.
Tools: `ToolBox.pm`, 11 (`Tools/PMTools.swift`). Launch:
`--autorun --backend apple --scenario pm`.

| beat | say | expect |
|---|---|---|
| 1 | Show me the iOS P1 issues that haven't been started. | `search_issues(project: iOS, status: todo, priority: P1)` — APP-3, the one right answer |
| 2 | Assign this one to Tanaka and move it to in progress. | `assign_issue(APP-3, Tanaka)` + `change_issue_status(APP-3, in_progress)` — the spec's multi-tool beat, both columns change at once |
| 3 | Push APP-5's due date to next Monday. | `change_due_date(APP-5, 2026-08-24)` — frozen-today date arithmetic |
| 4 | Bump APP-4 to P2. | `change_issue_priority(APP-4, P2)` |
| 5 | Comment on APP-9: keys rotated in staging. | `add_comment(APP-9, …)` |
| 6 | Close APP-11. | `close_issue(APP-11)` — the verb owns the call, beside change_issue_status |

日本語版: iOSの未着手のP1を見せて。→ この票を田中さん担当にして進行中にして。→ APP-5の期限を来週の月曜にずらして。→ APP-4をP2に上げて。→ APP-9にコメントして: ステージングでキー交換済み。→ APP-11をクローズして。

Design: everything the CRM pack measured, applied from day one — the
state carries counts and handles (projects, assignees, the frozen
today), never full rows; selection rows carry every handle (id,
project, title, priority, status, assignee, due); actions take ids
straight from the request or the selection; the bench fakes echo
dynamically from the first run (the starvation cost of neutral fakes
was re-measured on crm the same week and is not bought again).
Kana→romaji in the finder (田中・ログイン find their canned rows).
Cases: 18 EN + 18 JA — the three-filter headline search, the change_*
family one verb at a time, close-vs-status, creator-vs-assignee,
keyword search, due-by-Friday and next-Monday date arithmetic, entity
resolution through the selection, a no-call case and an ask-back
("Change the priority." — which issue, to what?).

Routing: **21/36 on Apple FM via the Mac lane** (2026-08-20, four
one-variable rounds: first run 20 → weekday in the state 22 → due_by
rename 19 → committed replicate 21; range 19–22 is the noise floor).
The rename moved "due by Friday" into the right bound in both
languages — the date value stayed wrong (weekday arithmetic is the
units recipe's newest datapoint). Stable instrument findings: the
get-prefix on every change_* verb (the look-first recipe, reproduced),
票を切って never reaching create_issue in Japanese (the model
re-purposed an existing issue instead), the Japanese undo failing
three different ways in three runs, one 57-call search sweep that
never acted, and a create_issue whose answer claimed the P1 its call
omitted.
