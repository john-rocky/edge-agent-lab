# Roadmap

The repo has three jobs, in this order:

1. **Show what is possible** — scenarios: vague human input becoming real
   app functionality, on device, with a recording.
2. **Show how to build it** — recipes: how to write tools a small model
   can route, how to resolve "that" into an argument, how to keep a model
   from grabbing tools it shouldn't.
3. **Show what to run it on** — the model table: measured, per scenario.
   The working hypothesis is that Apple's Foundation Models wins
   tool-calling on iOS outright — it is trained for exactly this. The
   interesting question the table answers is *where it doesn't reach*:
   Android, custom models, devices and languages without Apple
   Intelligence, and the failure modes the first run already exposed
   (it grabs a tool on requests that need none).

The unit of growth is a **scenario pack**: one directory holding a tool
set, a demo script, bench cases, and a recording. Adding a pack grows the
showcase and the benchmark at the same time — the bench never grows on
its own.

## Phases

**1. Photo editing** *(in progress)* — "a bit brighter", "warmer",
"crop it square": steering a parameter space with vague words. 15 tools;
the crop/resize/zoom and brightness/exposure/contrast neighborhoods make
it the first real similar-tools discrimination test.

**2. Compound device control, and one business scenario** — "help me
focus" becoming notifications + timer + brightness; a field report
(photo OCR → note → tomorrow-morning reminder) running fully offline.

**3. Vaguer inputs** — voice in (speech as the vaguest interface),
image in (VLM → tools; the case format's `image` field is reserved for
this).

**4. The same cases on Android** — the case format is
platform-independent on purpose; one scenario, one table, two platforms.

## Standing rails (grow with every pack, never ahead of one)

- Pack cases merge into the bench; the model table gets a row/column.
- Recipes are extracted from what the pack taught, into docs/.
- New models are added when a scenario needs them, not for coverage.

## Out of scope

General GUI agents (the Android screen agent stays its own track), cloud
routing, long-context understanding.
