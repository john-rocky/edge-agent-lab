# Polish-see — the perception control

Same seven fixtures as the polish loop, one question instead of a job:
"Is this photo too dark, too bright, too warm, too cool, washed out,
dull, or about right?" — scored by keyword over the prose
(`answerContains`, eyes on the answers required: substrings produce
false passes), with the call list required to stay empty. Three
conditions, one ladder (run-mac.sh):

- `polish-see` — sight alone, no tools in the room (the stage's look).
- `polish-see-vision` — the vision pack present, its own instructions.
- `polish-see-loop` — the pack present, the loop contract pinned.

Findings, Apple FM on the Mac (r28–r31, 2026-08-20):

- **With tools in the room the question is never answered.** Every
  case, under both instruction sets, became an edit call —
  auto_enhance or a brightness/exposure op — with the answer narrating
  the edit instead ("The photo now has more brightness."). The
  question's own words are the edit tools' guide words: asking about
  brightness summons the brightness tool. (r28: loop contract; r29:
  vision instructions.)
- **Without tools: "About right." to everything.** The −1.4 EV
  near-black photo, the blown highlights, the blue cast — all "about
  right" (r30/r31; the occasional keyword pass was a substring
  accident, "natural warmth" ⊂ warm).
- **Forced binary choice unlocks it.** "Too dark or too bright —
  answer with just one of the two" on the same fixtures: "Too dark.
  The image is underexposed, with shadows that are too deep and lack
  detail." and "Too bright." — both correct (r31).

So the loop's blindness is not blindness — it is the rail. The
perception exists, surfaces only when the answer space is forced, and
never reaches the loop's op choice on its own. Vague judgments land on
the rail exactly like vague amounts: the recipe.

Raw JSONL: ../../bench/results/2026-08-20-mac-r28/ … -r31/.
