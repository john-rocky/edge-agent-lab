#!/usr/bin/env python3
"""One row per bench run, in the shape the moment-seek lane reads rounds in.

    python3 rounds.py results/2026-08-21-mac-r4*/mac-video-moments-apple-fm.jsonl

Prints, per run: total, the old-40 subset, the JA/EN split, and the ritual
count. `report.py` scores a single run's cases; this compares runs, which is
the only way this lane reads anything — the aggregate belongs to the config
while any one case's verdict is a coin (docs/demo-playbook.md 経験則), so a
round is never read alone.

Other packs pass their own frozen reference and their own ritual tool:

    ROUNDS_BASELINE=results/2026-08-21-mac-l1/mac-photo-library-apple-fm.jsonl \
    ROUNDS_CASES=../scenarios/photo-library/cases.json ROUNDS_TOOL=check_photo \
        python3 rounds.py results/2026-08-21-mac-l*/mac-photo-library-apple-fm.jsonl

With ROUNDS_CASES set, each row is followed by a per-layer line — the cases'
own `layer` field, which the Swift runner ignores and which says which rung of
the cost gradient a correct run answers on. That column is the photo-library
pack's whole reason to exist: not how many cases passed, but whether the
cheap layers answered the questions they could.

Two choices worth knowing before trusting a number:

- **The subset column is defined by a frozen baseline round's case list** —
  r35 for moment-seek, the last round before that pack grew past 40 cases.
  Comparing totals across rounds with different denominators is meaningless;
  comparing the subset is not. Change the baseline only when its JSONL stops
  being the right frozen reference, and say so in script.md when you do.
- **The ritual column counts a tool, not a mistake.** It is the number that
  moved when nothing else did (7 cases / 7 calls at r35 → 18–19 of 46 from
  r39 on, across two binaries), which is what made "the ritual's floor
  belongs to the room, and it ratchets" measurable. Pass a different tool
  name to watch a different habit.

Validated against every published row for r38–r44; if it stops reproducing
them, this script is wrong, not the record.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BASELINE = os.environ.get(
    "ROUNDS_BASELINE",
    os.path.join(HERE, "results/2026-08-20-mac-r35/mac-video-moments-apple-fm.jsonl"))
TOOL = os.environ.get("ROUNDS_TOOL", "check_moment")
CASES = os.environ.get("ROUNDS_CASES")


def cases(path):
    """The scored case records — the runner also writes run/summary lines."""
    with open(path) as f:
        return [r for r in map(json.loads, f) if "pass" in r]


def layers():
    """case id -> the layer a correct run answers on (photo-library's field)."""
    if not CASES:
        return {}
    with open(os.path.join(HERE, CASES) if not os.path.isabs(CASES) else CASES) as f:
        return {c["id"]: c.get("layer", "?") for c in json.load(f)}


def main(paths):
    baseline = {r["case"] for r in cases(BASELINE)}
    layer = layers()
    for path in paths:
        recs = cases(path)

        def frac(sel):
            sel = list(sel)
            return f"{sum(1 for r in sel if r['pass'])}/{len(sel)}"

        hit = [r for r in recs if any(c["tool"] == TOOL for c in r["calls"])]
        calls = sum(sum(1 for c in r["calls"] if c["tool"] == TOOL) for r in recs)

        def routed(r):
            want = r["expected"][0] if r["expected"] else None
            got = r["calls"][0]["tool"] if r["calls"] else None
            return want == got

        print(
            os.path.basename(os.path.dirname(path)),
            f"total {frac(recs)}  base {frac(r for r in recs if r['case'] in baseline)}  "
            f"JA {frac(r for r in recs if r.get('lang') == 'ja')}  "
            f"EN {frac(r for r in recs if r.get('lang') != 'ja')}  "
            f"routed {sum(1 for r in recs if routed(r))}/{len(recs)}  "
            f"{TOOL} {len(hit)} cases / {calls} calls")
        if not layer:
            continue
        # Two numbers per layer: cases passed, and cases whose *first* call
        # was the tool the case expects. The second is the routing itself —
        # a case can lose on an argument or a tail and still have gone to the
        # right rung, and the pack is about the rung.
        groups = {}
        for r in recs:
            group = groups.setdefault(layer.get(r["case"], "?"), [0, 0, 0])
            group[2] += 1
            group[0] += 1 if r["pass"] else 0
            group[1] += 1 if routed(r) else 0
        print(
            "   layer " + "  ".join(
                f"{name} {g[0]}/{g[2]} (routed {g[1]}/{g[2]})"
                for name, g in sorted(groups.items())))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
