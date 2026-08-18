#!/usr/bin/env python3
"""Turn toolbench JSONL runs into a comparison table.

    ./report.py /tmp/toolbench-*.jsonl

One column per model, one row per case; then selection/args/no-op/latency
summaries split JP vs EN. The point of the first run is to reproduce the
hand-measured routing table in docs/model-routing.md — a mismatch there is a
harness bug until proven otherwise.
"""
import json
import sys
from collections import defaultdict


def load(paths):
    runs = defaultdict(dict)  # model -> case id -> record
    for path in paths:
        with open(path) as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("type") in ("run", "summary", "skip", "error"):
                    if rec.get("type") == "error":
                        print(f"note: {path}: run error: {rec.get('what')}")
                    continue
                runs[rec["model"]][rec["case"]] = rec
    return runs


def mark(rec):
    if rec is None:
        return "·"
    if rec.get("error"):
        return "E"
    if rec["pass"]:
        return "✓"
    # Selection right but arguments wrong is its own failure mode.
    return "args" if rec["selectionPass"] else "✗"


def main(paths):
    runs = load(paths)
    if not runs:
        sys.exit("no case records found")
    models = sorted(runs)
    cases = sorted({c for per in runs.values() for c in per})

    width = max(len(c) for c in cases) + 2
    print("case".ljust(width) + "".join(m[:26].ljust(28) for m in models))
    for case in cases:
        row = case.ljust(width)
        for model in models:
            rec = runs[model].get(case)
            called = ",".join(rec["called"]) if rec else ""
            row += f"{mark(rec)} {called}"[:26].ljust(28)
        print(row)

    print()
    for model in models:
        per = runs[model]
        for lang in ("en", "ja"):
            recs = [r for r in per.values() if r["lang"] == lang]
            if not recs:
                continue
            sel = sum(r["selectionPass"] for r in recs)
            args = sum(r["argsPass"] for r in recs)
            ok = sum(r["pass"] for r in recs)
            noop = [r for r in recs if not r["expected"]]
            noop_ok = sum(r["pass"] for r in noop)
            ms = sorted(r["ms"] for r in recs)
            median = ms[len(ms) // 2]
            print(
                f"{model}  {lang}: pass {ok}/{len(recs)}  "
                f"selection {sel}  args {args}  "
                f"no-op {noop_ok}/{len(noop)}  median {median / 1000:.1f}s"
            )


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
