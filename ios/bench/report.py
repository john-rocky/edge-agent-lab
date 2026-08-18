#!/usr/bin/env python3
"""Turn toolbench JSONL runs into a comparison table.

    ./report.py /tmp/toolbench-*.jsonl
    ./report.py -s photo-editing /tmp/toolbench-*.jsonl

One column per model, one row per case; then pass/no-op/latency summaries
split JP vs EN. `-s` names the scenario pack whose cases.json scores the
'○ reached' column (default coffee-run). The point of the first run was to
reproduce the hand-measured routing table in docs/model-routing.md — a
mismatch there is a harness bug until proven otherwise.
"""
import json
import os
import sys
from collections import defaultdict


def load_cases(scenario):
    path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "scenarios", scenario, "cases.json")
    with open(path) as f:
        return {c["id"]: c for c in json.load(f)}


def matches(matcher, value):
    if value is None:
        return False
    text = value if isinstance(value, str) else str(value)
    if "equals" in matcher:
        return text.lower() == matcher["equals"].lower()
    if "contains" in matcher:
        return matcher["contains"].lower() in text.lower()
    if "number" in matcher:
        try:
            return abs(float(value) - matcher["number"]) <= matcher.get("tol", 0)
        except (TypeError, ValueError):
            return False
    return False  # dateResolvesTo needs the run's date; not scored offline


def reached(rec, case):
    """Expected calls as an order-preserving subsequence of what was called.

    The strict in-app `pass` fails a model for a *reasonable* extra call —
    Apple FM grounds "find a cafe" with get_location first, then searches,
    which is better, not worse. This scores whether every expected call
    happened, in order, with matching args. A no-op case stays strict: any
    call fails it.
    """
    if rec.get("error"):
        return False
    calls = [(c["tool"], json.loads(c["args"]) if c["args"].startswith("{") else {})
             for c in rec["calls"]]
    if not case["expected"]:
        return not calls
    at = 0
    for want in case["expected"]:
        hit = None
        for i in range(at, len(calls)):
            if calls[i][0] != want["tool"]:
                continue
            if all(matches(m, calls[i][1].get(k)) for k, m in (want.get("args") or {}).items()):
                hit = i
                break
        if hit is None:
            return False
        at = hit + 1
    return True


def load(paths):
    runs = defaultdict(dict)  # model -> case id -> record
    for path in paths:
        with open(path) as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("type") in ("run", "summary", "skip", "error", "start", "abort"):
                    if rec.get("type") == "error":
                        print(f"note: {path}: run error: {rec.get('what')}")
                    continue
                runs[rec["model"]][rec["case"]] = rec
    return runs


def mark(rec, case):
    if rec is None:
        return "·"
    if rec.get("error"):
        return "E"
    if rec["pass"]:
        return "✓"
    if case and reached(rec, case):
        return "○"  # reached the expected calls, with extras around them
    return "✗"


def main(paths, scenario):
    runs = load(paths)
    if not runs:
        sys.exit("no case records found")
    try:
        case_defs = load_cases(scenario)
    except OSError:
        case_defs = {}
        print(f"note: no cases.json for scenario {scenario}; '○' scoring disabled")
    models = sorted(runs)
    cases = sorted({c for per in runs.values() for c in per})

    width = max(len(c) for c in cases) + 2
    print("case".ljust(width) + "".join(m[:26].ljust(28) for m in models))
    for case in cases:
        row = case.ljust(width)
        for model in models:
            rec = runs[model].get(case)
            called = ",".join(rec["called"]) if rec else ""
            row += f"{mark(rec, case_defs.get(case))} {called}"[:26].ljust(28)
        print(row)

    print("\n✓ exact  ○ expected calls reached with extras  ✗ missed  E error\n")
    for model in models:
        per = runs[model]
        for lang in ("en", "ja"):
            recs = [r for r in per.values() if r["lang"] == lang]
            if not recs:
                continue
            exact = sum(r["pass"] for r in recs)
            ok = sum(
                1 for r in recs
                if r["pass"] or (r["case"] in case_defs and reached(r, case_defs[r["case"]]))
            )
            noop = [r for r in recs if not r["expected"]]
            noop_ok = sum(r["pass"] for r in noop)
            ms = sorted(r["ms"] for r in recs)
            median = ms[len(ms) // 2]
            print(
                f"{model}  {lang}: reached {ok}/{len(recs)} (exact {exact})  "
                f"no-op {noop_ok}/{len(noop)}  median {median / 1000:.1f}s"
            )


if __name__ == "__main__":
    args = sys.argv[1:]
    scenario = "coffee-run"
    if "-s" in args:
        at = args.index("-s")
        scenario = args[at + 1]
        del args[at : at + 2]
    if not args:
        sys.exit(__doc__)
    main(args, scenario)
