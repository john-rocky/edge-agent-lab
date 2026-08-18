#!/usr/bin/env python3
"""The prompts the video shows, read out of the Kotlin the app actually sends.

A slide that quotes a prompt is worthless the moment the prompt changes, and the
first cut had already drifted: it dropped a "by" from the planner's opening line
and paraphrased "What you have already done:" as "Already done:". So nothing is
retyped here. Everything is parsed from the source and rendered verbatim, with
elisions marked "…" where a card cannot hold the whole thing.
"""
import os
import re

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SDK = f"{REPO}/sdk/src/main/java/com/edgeagent/sdk"


def _read(path):
    with open(path) as fh:
        return fh.read()


def vendor_system_prompt():
    """`Grounding.POINT_SYSTEM_PROMPT` — the vendor's, copied verbatim."""
    src = _read(f"{SDK}/Grounding.kt")
    block = src[src.index("const val POINT_SYSTEM_PROMPT"):src.index("const val BOX_SYSTEM_PROMPT")]
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', block)
    text = "".join(p.encode().decode("unicode_escape") for p in parts)
    return text.strip()


def tap_loop_prompt(goal):
    """`Agent.promptFor` — the one-question loop."""
    src = _read(f"{SDK}/Agent.kt")
    block = src[src.index("fun promptFor(goal: String): String"):]
    block = block[:block.index("\n\n")]
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', block)
    text = "".join(p.encode().decode("unicode_escape") for p in parts)
    return text.replace("$goal", goal).strip()


def planner_prompt(goal, done):
    """`Planning.promptFor` — ours, the one that chooses the action."""
    src = _read(f"{SDK}/Plan.kt")
    body = src[src.index('return """') + len('return """'):]
    body = body[:body.index('""".trimIndent()')]
    lines = [line[12:] if line.startswith(" " * 12) else line.strip()
             for line in body.split("\n")]
    text = "\n".join(lines).strip("\n")
    history = "Nothing yet." if not done else "\n".join(
        f"{i + 1}. {s}" for i, s in enumerate(done))
    return text.replace("$goal", goal).replace("$history", history)


def wrapped(text, width):
    """Hard-wrap for a fixed-width card, keeping blank lines."""
    out = []
    for line in text.split("\n"):
        if len(line) <= width:
            out.append(line)
            continue
        indent = " " * (len(line) - len(line.lstrip()))
        current = ""
        for word in line.split(" "):
            probe = f"{current} {word}".strip()
            if len(probe) + len(indent) <= width or not current:
                current = probe
            else:
                out.append(indent + current)
                current = word
        out.append(indent + current)
    return out


if __name__ == "__main__":
    print("--- vendor ---");   print(vendor_system_prompt())
    print("--- tap loop ---"); print(tap_loop_prompt("open the notification history"))
    print("--- planner ---");  print(planner_prompt("search settings for wifi", []))
