# Documents — an Acrobat / Goodnotes menu, said out loud, on a real PDF

The fourth market-in pack: a PDF app's menu in its own words — go to a
page, delete / move / rotate / insert pages, highlight words, remove
highlights, stick a note, sign, search, save as — on a real PDF through
PDFKit. The document is the newest PDF in the app's Documents (drop one in
with Files.app) or, when there is none, a six-page lease agreement the app
draws itself. State in, tools out: every message opens with the document
as it is — page count, the open page, each page's title (its first line),
what is annotated — so "the cover" and "the rules page" are page numbers
the model reads, and "the last page" is the page count. Tools:
`ToolBox.docs`, 14 (`Tools/DocTools.swift`, with `add_watermark` — a big
translucent word across every page — and `extract_pages` to a new file).
Launch: `--autorun --backend apple --scenario docs`; `--voice` for spoken
beats; chat: `--scenario docs` without `--autorun`. The stage shows the
open page, big, and the pages as a strip under it.

Routing: **33/36 on Apple FM via the Mac lane** (2026-08-19, the best of
the seven); not yet run on the phone. What those runs taught (fixes in): a canned bench result
that echoed the wrong page ("on page 3" against a go_to_page(5)) made
the model retry the call — the fake-results recipe, again; and asked
「敷金は何ページ?」 the model answered from the page *titles* in the
state ("Rent and Deposit" → page 3) instead of searching — the
instructions now say the state lists titles, not contents.

| beat | say | expect |
|---|---|---|
| 1 | Which pages mention the deposit? | `search_document(deposit)` — pages 3 (3×) and 4 (1×), a table; nothing changes |
| 2 | Go to the first of those and highlight every 'deposit' in yellow. | `go_to_page(3)` → `highlight_text(deposit, yellow)` — a chain on beat 1's answer; the page on stage turns yellow in four places |
| 3 | Add a note: check this with the landlord. | `add_note(...)` on the open page — a note icon top-right |
| 4 | Delete the cover page. | `delete_page(1)` — "cover" is page 1 by its title in the state; the strip loses a page |
| 5 | Move the house rules page to the end. | `move_page(4, to: 5)` — after the delete, rules is page 4 and the end is 5; the state has both numbers |
| 6 | Sign the last page. | `sign_page(5)` — an ink signature bottom-right of the signatures page |
| 7 | Save it as 'lease-signed'. | `save_as(lease-signed)` — `saved-lease-signed.pdf` in Documents |

日本語版(未実測):

| beat | 言う |
|---|---|
| 1 | 敷金について書いてあるのは何ページ? |
| 2 | 最初のページを開いて、「deposit」を全部黄色でハイライトして。 |
| 3 | メモを付けて:「大家に確認する」。 |
| 4 | 表紙を削除して。 |
| 5 | ハウスルールのページを最後に移動して。 |
| 6 | 最後のページに署名して。 |
| 7 | 「lease-signed」という名前で保存して。 |

What the model reads (ahead of the words, every beat):

    [App state] Document: "Lease Agreement", 6 pages, open at page 1.
    Pages: 1 Lease Agreement; 2 Parties; 3 Rent and Deposit; 4 Term;
    5 House Rules; 6 Signatures. Annotations: none.

    Which pages mention the deposit?

After beat 4 the state reads `5 pages … Pages: 1 Parties; 2 Rent and
Deposit; 3 Term; 4 House Rules; 5 Signatures. Annotations: page 2: 3
highlights, 1 note; page 3: 1 highlight.` — beat 5's numbers come from
there, not from the beat before.

Design

- **Pages are named by their first line**, in the state, every beat. That
  is what makes "the cover", "the rules page", "the signatures page" into
  numbers without a lookup tool, and it re-numbers itself after a delete
  or a move — the model is told what its own calls did.
- **Highlights are the document's own text.** `highlight_text(text,
  color)` runs `PDFDocument.findString` and puts a `.highlight`
  annotation on every line of every match; `remove_highlights(this_page |
  all_pages)` takes them off; `search_document` is the same search with
  no change — a query tool, scored on its argument.
- **The signature is ink**: a Bézier squiggle as a `.ink` PDFAnnotation,
  bottom-right of the page named. `sign_page` takes a number, so "sign the
  last page" is the page count read from the state.
- **On screen**: the open page rendered with its annotations
  (`PDFPage.thumbnail`), the pages as a strip with the open one outlined
  and a dot on annotated ones. Search posts a table.
- **The sample lease** (`SampleLease`) has "deposit" on pages 3 and 4, a
  cover, and a signatures page — enough for every beat to mean something,
  nothing in it a real agreement.

Bench: 15 EN + 15 JA in `cases.json`, each with the `state` block it is
scored against (the fresh document / page 3 open with highlights). The JA
search case leaves the query unscored (「敷金」 or "deposit" are both
right). `SCENARIO=docs ./run-device.sh` (toolset `docs`).

When the phone is back (what to read in `run.log`)

- `DOC loaded — Document: "Lease Agreement", 6 pages …` (or the name of
  a PDF you dropped in). If a dropped-in PDF has no text layer, page
  titles read "(blank)" and highlights find nothing — use the sample.
- Beat 2 must be two calls, `go_to_page(3)` before `highlight_text`; the
  page on stage must show yellow.
- Beat 5's `move_page` arguments must be 4 → 5 (post-delete numbers), not
  5 → 6.
- Beat 6 must sign page 5 (the count after the delete), and the strip's
  last thumbnail must show the ink.
- Beat 7 leaves `saved-lease-signed.pdf` in Documents; open it in Files —
  highlights, note and signature are in the file.
