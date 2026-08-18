#!/usr/bin/env python3
"""Grounding truth harness for LFM2.5-VL on the LiteRT-LM runtime.

Runs the desktop `litert-lm` CLI over a screenshot with the vendor's point /
box grounding system prompt, parses the JSON the model emits, scores it against
hand-labelled ground-truth boxes, and renders an overlay PNG.

This is the Mac-side reference for the on-device Android path: same prompt,
same parser, same coordinate mapping. If a target lands here and misses on the
device, the difference is the engine, not the prompt.

Usage:
  ground_probe.py --shot shots/settings.png --truth shots/settings.json \
      --model /path/model.litertlm [--backend cpu] [--mode point|box] \
      [--out out/settings]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time

# Vendor system prompts, verbatim from the official LFM2.5-VL WebGPU demo
# (huggingface.co/spaces/LiquidAI/LFM2.5-VL-3B-WebGPU, src/main.js).
POINT_SYSTEM_PROMPT = """When asked for points corresponding to objects or regions, return a valid JSON array.
Each array item must be an object with:
- image_id: the 0-based index of the image
- point_2d: [x, y] normalized integer coordinates in [0, 1000]
- label: a concise label you choose for the predicted object or region

Return one item per visible matching object or region. Return [] if none are visible."""

BOX_SYSTEM_PROMPT = """When asked for bounding boxes for objects, return a valid JSON array.
Each array item must be an object with:
- image_id: the 0-based index of the image
- bbox_2d: [xmin, ymin, xmax, ymax] normalized integer coordinates in [0, 1000]
- label: a concise label you choose for the predicted object or region

Return one item per visible matching object or region. Return [] if none are visible."""

DEFAULT_CLI = os.path.expanduser(
    "~/code/litertlm-convert/.venv-lt016/bin/litert-lm"
)


# ---------- parsing (port of the vendor parser in src/grounding.js) ----------

_NUM = r"(-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)"
_BARE_BOX = re.compile(r"\[\s*%s\s*,\s*%s\s*,\s*%s\s*,\s*%s\s*\]" % ((_NUM,) * 4))
_BARE_POINT = re.compile(r"\[\s*%s\s*,\s*%s\s*\]" % ((_NUM,) * 2))


def _normalize(values, length):
    """Accept either 0..1 floats or 0..1000 ints; return 0..1000 ints."""
    if len(values) != length:
        return None
    if all(0.0 <= v <= 1.0 for v in values):
        return [round(v * 1000) for v in values]
    if all(float(v).is_integer() and 0 <= v <= 1000 for v in values):
        return [int(v) for v in values]
    return None


def parse_grounding(text: str):
    """Return a list of {'label','type','coords'} or [] if nothing parseable."""
    stripped = text.strip()
    # The model sometimes wraps the array in a ```json fence.
    fence = re.search(r"```(?:json)?\s*(.+?)```", stripped, re.S)
    if fence:
        stripped = fence.group(1).strip()
    try:
        parsed = json.loads(stripped)
    except json.JSONDecodeError:
        parsed = None

    out = []
    if isinstance(parsed, list):
        for item in parsed:
            if not isinstance(item, dict):
                continue
            label = str(item.get("label", "")).strip() or "?"
            if "point_2d" in item:
                coords = _normalize(list(item["point_2d"]), 2)
                if coords:
                    out.append({"label": label, "type": "point", "coords": coords})
            elif "bbox_2d" in item:
                coords = _normalize(list(item["bbox_2d"]), 4)
                if coords and coords[2] > coords[0] and coords[3] > coords[1]:
                    out.append({"label": label, "type": "box", "coords": coords})
        if out:
            return out

    # Fallback: bare [x,y] / [x,y,x,y] arrays in prose.
    for m in _BARE_BOX.finditer(stripped):
        coords = _normalize([float(g) for g in m.groups()], 4)
        if coords and coords[2] > coords[0] and coords[3] > coords[1]:
            out.append({"label": "box", "type": "box", "coords": coords})
    if out:
        return out
    for m in _BARE_POINT.finditer(stripped):
        coords = _normalize([float(g) for g in m.groups()], 2)
        if coords:
            out.append({"label": "point", "type": "point", "coords": coords})
    return out


# ---------- runtime ----------


def run_cli(cli, model, prompt, image, backend, vision_backend, max_tokens):
    cmd = [
        cli, "run", model,
        "--prompt", prompt,
        "--attachment", image,
        "--backend", backend,
        "--cache", "no",
        "--temperature", "0",
        "--seed", "0",
    ]
    # Trap (RESULTS.md): --max-num-tokens + --attachment + --backend gpu fails
    # at engine creation. Only pass the cap on CPU.
    if max_tokens and backend == "cpu":
        cmd += ["--max-num-tokens", str(max_tokens)]
    if vision_backend:
        cmd += ["--vision-backend", vision_backend]
    t0 = time.time()
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    return proc.stdout.strip(), proc.stderr.strip(), proc.returncode, time.time() - t0


# ---------- scoring ----------


def hit(pred, truth_box):
    """A point hits when it falls inside the ground-truth box (norm [0,1000])."""
    x0, y0, x1, y1 = truth_box
    if pred["type"] == "point":
        x, y = pred["coords"]
        return x0 <= x <= x1 and y0 <= y <= y1
    # For a box prediction, score its centre.
    bx0, by0, bx1, by1 = pred["coords"]
    cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
    return x0 <= cx <= x1 and y0 <= cy <= y1


# ---------- overlay ----------


def draw_overlay(shot_path, rows, out_path):
    from PIL import Image, ImageDraw, ImageFont

    img = Image.open(shot_path).convert("RGB")
    W, H = img.size
    d = ImageDraw.Draw(img, "RGBA")
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 34)
    except OSError:
        font = ImageFont.load_default()

    for row in rows:
        ok = row["hit"]
        colour = (46, 204, 113) if ok else (231, 76, 60)
        tb = row["truth"]
        d.rectangle(
            [tb[0] / 1000 * W, tb[1] / 1000 * H, tb[2] / 1000 * W, tb[3] / 1000 * H],
            outline=(255, 255, 255, 140), width=3,
        )
        for pred in row["preds"]:
            if pred["type"] == "point":
                x = pred["coords"][0] / 1000 * W
                y = pred["coords"][1] / 1000 * H
                r = 26
                d.ellipse([x - r, y - r, x + r, y + r], outline=colour, width=7)
                d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=colour)
            else:
                c = pred["coords"]
                d.rectangle(
                    [c[0] / 1000 * W, c[1] / 1000 * H, c[2] / 1000 * W, c[3] / 1000 * H],
                    outline=colour, width=6,
                )
                x, y = c[0] / 1000 * W, c[1] / 1000 * H
            d.text((x + 32, y - 20), pred["label"], fill=colour, font=font)

    img.save(out_path)
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot", required=True)
    ap.add_argument("--truth", required=True, help="JSON: [{target, prompt, box}]")
    ap.add_argument("--model", required=True)
    ap.add_argument("--cli", default=DEFAULT_CLI)
    ap.add_argument("--backend", default="cpu", choices=["cpu", "gpu"])
    ap.add_argument("--vision-backend", default=None, choices=[None, "cpu", "gpu"])
    ap.add_argument("--mode", default="point", choices=["point", "box"])
    ap.add_argument("--max-tokens", type=int, default=2048)
    ap.add_argument("--out", default="out/probe")
    args = ap.parse_args()

    truth = json.load(open(args.truth))
    system = POINT_SYSTEM_PROMPT if args.mode == "point" else BOX_SYSTEM_PROMPT
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)

    rows, hits = [], 0
    for case in truth:
        prompt = f"{system}\n\n{case['prompt']}"
        text, err, rc, secs = run_cli(
            args.cli, args.model, prompt, args.shot,
            args.backend, args.vision_backend, args.max_tokens,
        )
        preds = parse_grounding(text) if rc == 0 else []
        ok = any(hit(p, case["box"]) for p in preds)
        hits += ok
        rows.append({
            "target": case["target"], "truth": case["box"], "preds": preds,
            "hit": ok, "raw": text[:400], "rc": rc, "secs": round(secs, 1),
            "err": err[-300:] if rc else "",
        })
        flag = "hit " if ok else "MISS"
        coords = [p["coords"] for p in preds] or "unparseable"
        print(f"[{flag}] {case['target']:<24} {coords}  ({secs:.1f}s)"
              + (f"  rc={rc}" if rc else ""))

    summary = {
        "model": os.path.basename(args.model), "backend": args.backend,
        "vision_backend": args.vision_backend, "mode": args.mode,
        "shot": os.path.basename(args.shot),
        "hits": hits, "total": len(rows), "rows": rows,
    }
    json.dump(summary, open(args.out + ".json", "w"), indent=2)
    png = draw_overlay(args.shot, rows, args.out + ".png")
    print(f"\n{hits}/{len(rows)} inside the target  ->  {png}")
    return 0 if hits == len(rows) else 1


if __name__ == "__main__":
    sys.exit(main())
