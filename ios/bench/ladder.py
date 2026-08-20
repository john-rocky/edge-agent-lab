#!/usr/bin/env python3
"""Partition a pack's cases across a ladder rung's tool subsets.

The tool-count ladder (business-packs.md, evaluation program #1) runs the
same cases at 5/10/20/41 tools. A subset that lacks a case's correct tools
measures nothing, so each rung is a family of subsets ("groups", ladder.json)
and every case belongs to exactly one group: the first group in file order
whose tool list covers the case's expected calls. Ask and noop cases expect
no call, so they land in the rung's first group. This script is that rule —
run-mac.sh asks it for the filtered cases file and the --only list, and
`check` proves every rung is a partition before anything is measured.

  ladder.py check                  verify every rung partitions its pack's cases
  ladder.py cases <group>          the group's cases, JSON on stdout
  ladder.py tools <group>          comma-joined tool list for --only
  ladder.py pack <group>           the group's pack (cases dir + instructions pin)
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCENARIOS = HERE.parent / "scenarios"


def load_ladder():
    ladder = json.loads((HERE / "ladder.json").read_text())
    ladder.pop("_comment", None)
    return ladder


def load_cases(pack):
    return json.loads((SCENARIOS / pack / "cases.json").read_text())


def assign(rung_groups, cases):
    """case id -> group name, first group in file order covering the case."""
    homes = {}
    for case in cases:
        expected = {e["tool"] for e in case.get("expected", [])}
        home = next(
            (name for name, g in rung_groups if expected <= set(g["tools"])), None)
        if home is None:
            sys.exit(f"ladder.json: no group of this rung covers {case['id']} "
                     f"(expects {sorted(expected)})")
        homes[case["id"]] = home
    return homes


def rung_groups_of(ladder, rung):
    return [(name, g) for name, g in ladder.items() if g["rung"] == rung]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    ladder = load_ladder()
    command = sys.argv[1]

    if command == "check":
        for rung in dict.fromkeys(g["rung"] for g in ladder.values()):
            groups = rung_groups_of(ladder, rung)
            pack = groups[0][1]["pack"]
            cases = load_cases(pack)
            homes = assign(groups, cases)
            counts = {name: sum(1 for h in homes.values() if h == name)
                      for name, _ in groups}
            sizes = {len(g["tools"]) for _, g in groups}
            print(f"{rung}: {len(cases)} cases over {counts} (tool counts {sorted(sizes)})")
        return

    if len(sys.argv) != 3 or command not in ("cases", "tools", "pack"):
        sys.exit(__doc__)
    group = sys.argv[2]
    if group not in ladder:
        sys.exit(f"unknown ladder group {group} — see ladder.json")
    spec = ladder[group]

    if command == "pack":
        print(spec["pack"])
    elif command == "tools":
        print(",".join(spec["tools"]))
    else:
        cases = load_cases(spec["pack"])
        homes = assign(rung_groups_of(ladder, spec["rung"]), cases)
        mine = [c for c in cases if homes[c["id"]] == group]
        if not mine:
            sys.exit(f"{group}: no cases assigned — a group that measures nothing")
        json.dump(mine, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
