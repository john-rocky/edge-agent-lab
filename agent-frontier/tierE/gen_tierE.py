#!/usr/bin/env python3
"""gen_tierE.py — generate the Tier-E long-horizon endurance tasks.

Tier E (kickoff ladder): a 20+ tool-call chain to find WHERE round-count degrades a small model
("long-distance endurance"). Two failure modes, one task each — both reuse the existing Runner,
Tools, and Checker unchanged (no new assertion kinds), so they self-test on CPU like P0/P1:

  tierE_breadcrumb_chain  — sequential DEPENDENCY: each read reveals the next id. Tests whether
                            the model keeps the thread over N hops. Degradation profile = the
                            longest run of codewords it collected before losing the trail.
  tierE_batch_followups   — REPETITION: one reminder per calendar meeting, N meetings. Tests
                            whether per-item quality degrades late in a long uniform chain.
                            Degradation profile = which of the N per-item checks passed vs item
                            index (item k lands around round k → pass/fail(k) is the curve).

Both use MANY single-item assertions on purpose: the Checker reports one CheckResult per
assertion, so the pass/fail breakdown *is* the degradation profile — no new checker code.

  python3 gen_tierE.py            # canonical N=20 → the two committed task files
  python3 gen_tierE.py 30 sweep   # emit tierE_*_n30.json (for the GPU N-sweep; not committed)

Parameterized so the GPU session can sweep N (10/20/30/40) to locate the onset.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# 20 distinct, non-substring codewords (NATO) and full names with unique, non-substring surnames.
CODEWORDS = ["ALFA","BRAVO","CHARLIE","DELTA","ECHO","FOXTROT","GOLF","HOTEL","INDIA","JULIET",
             "KILO","LIMA","MIKE","NOVEMBER","OSCAR","PAPA","QUEBEC","ROMEO","SIERRA","TANGO",
             "UNIFORM","VICTOR","WHISKEY","XRAY","YANKEE","ZULU","ANCHOR","BEACON","CANYON","DUNE",
             "EMBER","FJORD","GRANITE","HARBOR","IVORY","JADE","KELP","LOTUS","MARROW","NEBULA"]
SECRET = "MIDNIGHT-LANTERN-77"
NAMES = [("Riley","Okonkwo"),("Sam","Ramirez"),("Noa","Nakamura"),("Ines","Petrov"),("Omar","Haddad"),
         ("Kira","Bergstrom"),("Luca","Vasquez"),("Aya","Kowalski"),("Theo","Fitzgerald"),("Mei","Larsen"),
         ("Dev","Delacroix"),("Pia","Yamada"),("Gus","Oyelaran"),("Vera","Persson"),("Ike","Guptill"),
         ("Rosa","Marchetti"),("Tomas","Ibrahim"),("Nadia","Novak"),("Bram","Escobar"),("Hana","Whitfield"),
         ("Cato","Montoya"),("Elin","Thackeray"),("Jun","Ashford"),("Fola","Brennan")]

def _no_substring(items, label):
    up = [s.upper() for s in items]
    for i, a in enumerate(up):
        for j, b in enumerate(up):
            if i != j and a in b:
                raise SystemExit(f"{label}: '{items[i]}' is a substring of '{items[j]}' — checks would collide")

def breadcrumb(n):
    words = CODEWORDS[:n]
    _no_substring(words + [SECRET], "codewords")
    corpus = []
    for k in range(n):
        cid = f"c{k:02d}"; word = words[k]
        if k < n - 1:
            body = f"Waypoint {k}. Codeword: {word}. Next, read c{k+1:02d}."
        else:
            body = f"Waypoint {k}. Codeword: {word}. This is the end of the trail. The final passphrase is {SECRET}."
        corpus.append({"id": cid, "title": ("Trailhead" if k == 0 else f"Waypoint {k}"), "body": body})
    # decoys: unrelated docs so search isn't trivial and "read everything" doesn't collect the words
    for did, t, b in [("x1","Office wifi","The guest wifi password rotates monthly."),
                      ("x2","Coffee order","Oat milk flat white, no sugar for the 10am."),
                      ("x3","Parking","Level 3 is reserved for visitors on weekdays."),
                      ("x4","Fire drill","The muster point is the north lawn by the flagpole."),
                      ("x5","Printer","The 5th-floor printer jams on thick card stock.")]:
        corpus.append({"id": did, "title": t, "body": b})
    checks = [{"kind": "answer_contains", "all_of": [w]} for w in words]
    checks.append({"kind": "answer_contains", "all_of": [SECRET]})
    checks.append({"kind": "tool_called", "tool": "corpus.read", "min_count": n})
    mock = [{"call": {"tool": "corpus.search", "args": {"query": "trailhead"}}}]
    mock += [{"call": {"tool": "corpus.read", "args": {"id": f"c{k:02d}"}}} for k in range(n)]
    mock.append({"finish": "Codewords in order: " + ", ".join(words) + ". Final passphrase: " + SECRET + "."})
    return {
        "id": "tierE_breadcrumb_chain", "title": f"Follow a {n}-hop document trail", "tier": "tierE",
        "source": "kickoff Tier E (long-horizon endurance): a 20+ dependent-read chain to find where a "
                  "small model loses the thread. Synthetic 'trail' corpus so the chain is controllable "
                  "and copyright-free; each read reveals the next id (true sequential dependency).",
        "spec": "Follow the trail through my documents. Start at the document titled 'Trailhead', then "
                "follow each 'Next, read cNN' pointer from one waypoint to the next, all the way to the "
                "end. Collect every codeword you see, in order. In your final answer, list all the "
                "codewords and the final passphrase.",
        "now": "2026-07-14T09:00:00-07:00", "timezone": "America/Los_Angeles", "max_rounds": n + 8,
        "tool_allowlist": ["corpus.search", "corpus.read"],
        "initial_state": {"corpus": corpus},
        "final_check": {"all": checks},
        "mock_solution": mock,
    }

def batch(n):
    surnames = [ln for _, ln in NAMES[:n]]
    _no_substring(surnames, "surnames")
    cal = []
    for k in range(n):
        first, last = NAMES[k]; hh = 8 + (k % 9)
        cal.append({"id": f"m{k:02d}", "title": f"Sync with {first} {last}",
                    "start": f"2026-07-14T{hh:02d}:00:00-07:00", "end": f"2026-07-14T{hh:02d}:30:00-07:00",
                    "attendees": [f"{first} {last}"]})
    checks = [{"kind": "reminder_exists", "title_contains": NAMES[k][1]} for k in range(n)]
    checks.append({"kind": "reminder_count", "equals": n})
    mock = [{"call": {"tool": "calendar.list", "args": {"date": "2026-07-14"}}}]
    for first, last in NAMES[:n]:
        mock.append({"call": {"tool": "reminders.create",
                              "args": {"title": f"Follow up with {first} {last}", "due": "2026-07-15T09:00:00-07:00"}}})
    mock.append({"finish": f"Created {n} follow-up reminders, one per meeting."})
    return {
        "id": "tierE_batch_followups", "title": f"One follow-up reminder for each of {n} meetings", "tier": "tierE",
        "source": "kickoff Tier E (long-horizon endurance): iterate over N calendar items creating one "
                  "reminder each, to measure whether per-item quality degrades as the chain lengthens "
                  "(later items dropped / duplicated). Each per-item check is a separate assertion so the "
                  "pass/fail breakdown is the degradation curve.",
        "spec": f"I have {n} meetings on my calendar today. For EACH meeting, create exactly one reminder "
                f"titled 'Follow up with <the attendee's full name>' due tomorrow at 9:00 AM. Do not skip "
                f"any meeting and do not create duplicates.",
        "now": "2026-07-14T09:00:00-07:00", "timezone": "America/Los_Angeles", "max_rounds": 2 * n + 8,
        "tool_allowlist": ["calendar.list", "calendar.get", "reminders.create", "reminders.list"],
        "initial_state": {"calendar": cal, "reminders": []},
        "final_check": {"all": checks},
        "mock_solution": mock,
    }

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    sweep = len(sys.argv) > 2 and sys.argv[2] == "sweep"
    for t in (breadcrumb(n), batch(n)):
        name = t["id"] + (f"_n{n}" if sweep else "") + ".json"
        p = os.path.join(HERE, name)
        json.dump(t, open(p, "w"), indent=2)
        print(f"wrote {name:34s} mock_steps={len(t['mock_solution']):3d} checks={len(t['final_check']['all']):3d} "
              f"max_rounds={t['max_rounds']}")
