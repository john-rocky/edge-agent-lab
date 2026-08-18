#!/usr/bin/env python3
"""Torch/HF grounding reference for LFM2.5-VL.

Same screenshot, same vendor system prompt, same scoring as tools/ground_probe.py
— but through plain HF transformers instead of the LiteRT-LM runtime. This is the
control that says whether a grounding miss is a model/prompt limit or a runtime
(conversion / engine) defect.

Usage:
  hf_ground_ref.py --shot shot.png --truth truth.json \
      [--model LiquidAI/LFM2.5-VL-3B] [--max-tokens 96] [--out out/hf]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ground_probe import POINT_SYSTEM_PROMPT, parse_grounding, hit, draw_overlay  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot", required=True)
    ap.add_argument("--truth", required=True)
    ap.add_argument("--model", default="LiquidAI/LFM2.5-VL-3B")
    ap.add_argument("--max-tokens", type=int, default=96)
    ap.add_argument("--system-role", action="store_true",
                    help="Send the grounding prompt as a system turn instead of "
                         "prefixing it to the user turn (the CLI has no system flag, "
                         "so the default matches the runtime probe).")
    ap.add_argument("--out", default="out/hf_ground")
    args = ap.parse_args()

    import torch
    from PIL import Image
    from transformers import AutoModelForImageTextToText, AutoProcessor

    truth = json.load(open(args.truth))
    image = Image.open(args.shot).convert("RGB")
    print(f"image {image.size}")

    processor = AutoProcessor.from_pretrained(args.model)
    model = AutoModelForImageTextToText.from_pretrained(args.model, dtype=torch.bfloat16)
    model.eval()

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    rows, hits = [], 0
    for case in truth:
        if args.system_role:
            messages = [
                {"role": "system", "content": [{"type": "text", "text": POINT_SYSTEM_PROMPT}]},
                {"role": "user", "content": [
                    {"type": "image", "image": image},
                    {"type": "text", "text": case["prompt"]},
                ]},
            ]
        else:
            messages = [{"role": "user", "content": [
                {"type": "image", "image": image},
                {"type": "text", "text": f"{POINT_SYSTEM_PROMPT}\n\n{case['prompt']}"},
            ]}]
        inputs = processor.apply_chat_template(
            messages, add_generation_prompt=True, tokenize=True,
            return_dict=True, return_tensors="pt")
        t0 = time.time()
        with torch.no_grad():
            out = model.generate(**inputs, max_new_tokens=args.max_tokens, do_sample=False)
        text = processor.decode(out[0][inputs["input_ids"].shape[1]:],
                                skip_special_tokens=True).strip()
        secs = time.time() - t0
        preds = parse_grounding(text)
        ok = any(hit(p, case["box"]) for p in preds)
        hits += ok
        rows.append({"target": case["target"], "truth": case["box"], "preds": preds,
                     "hit": ok, "raw": text[:400], "secs": round(secs, 1)})
        print(f"[{'hit ' if ok else 'MISS'}] {case['target']:<24} "
              f"{[p['coords'] for p in preds] or text[:60]!r}  ({secs:.1f}s)")

    summary = {"backend": "hf-torch-bf16", "model": args.model,
               "shot": os.path.basename(args.shot),
               "prompt_role": "system" if args.system_role else "user",
               "image_size": list(image.size),
               "hits": hits, "total": len(rows), "rows": rows}
    json.dump(summary, open(args.out + ".json", "w"), indent=2)
    draw_overlay(args.shot, rows, args.out + ".png")
    print(f"\n{hits}/{len(rows)} inside the target  ->  {args.out}.png")
    return 0 if hits == len(rows) else 1


if __name__ == "__main__":
    sys.exit(main())
