#!/usr/bin/env python3
"""One row per bench run, in the shape the moment-seek lane reads rounds in.

    python3 rounds.py results/2026-08-21-mac-r4*/mac-video-moments-apple-fm.jsonl

Prints, per run: total, the old-40 subset, the JA/EN split, and the ritual
count. `report.py` scores a single run's cases; this compares runs, which is
the only way this lane reads anything — the aggregate belongs to the config
while any one case's verdict is a coin (docs/demo-playbook.md 経験則), so a
round is never read alone.

Two choices worth knowing before trusting a number:

- **The old-40 subset is defined by r35's case list**, the last round before
  the pack grew past 40 cases. Comparing totals across rounds with different
  denominators is meaningless; comparing the subset is not. Change the
  baseline only if r35's JSONL stops being the right frozen reference, and
  say so in script.md when you do.
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
BASELINE = os.path.join(
    HERE, "results/2026-08-20-mac-r35/mac-video-moments-apple-fm.jsonl")
TOOL = os.environ.get("ROUNDS_TOOL", "check_moment")


def cases(path):
    """The scored case records — the runner also writes run/summary lines."""
    with open(path) as f:
        return [r for r in map(json.loads, f) if "pass" in r]


def main(paths):
    baseline = {r["case"] for r in cases(BASELINE)}
    for path in paths:
        recs = cases(path)

        def frac(sel):
            sel = list(sel)
            return f"{sum(1 for r in sel if r['pass'])}/{len(sel)}"

        hit = [r for r in recs if any(c["tool"] == TOOL for c in r["calls"])]
        calls = sum(sum(1 for c in r["calls"] if c["tool"] == TOOL) for r in recs)
        print(
            os.path.basename(os.path.dirname(path)),
            f"total {frac(recs)}  old40 {frac(r for r in recs if r['case'] in baseline)}  "
            f"JA {frac(r for r in recs if r.get('lang') == 'ja')}  "
            f"EN {frac(r for r in recs if r.get('lang') != 'ja')}  "
            f"{TOOL} {len(hit)} cases / {calls} calls")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
