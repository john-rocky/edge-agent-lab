#!/usr/bin/env python3
"""One explainer per wait, each one a turn of the conversation, laid out wide.

What a viewer needs is the sequence — what goes to the model, what comes back,
what is done with it, and what the next turn is given. So every beat here is a
transcript, and in 16:9 the two halves of a turn can sit side by side instead of
scrolling past one another.

Strings marked "from this run" are copied from logcat for the footage on either
side of the beat. Prompt text is never retyped: `demo_prompts` reads it out of
the Kotlin the app actually sends.
"""
import os

import demo_prompts
from demo_chrome import (W, H, INK, DIM, FAINT, LINE, GREEN, BLUE, MONO, BOLD, REG,
                         explain_base, font, fitted, waited)

FPS = 30
ORANGE = (255, 176, 102)

LEFT, RIGHT = 60, 1000          # the two columns
COL_W = 830
TOP = 360                       # under the title block
BOTTOM = 930


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def at(t, start, dur=0.6):
    return ease((t - start) / dur) if dur else 0.0


def chip(d, x, y, text, colour=GREEN, bg=(15, 32, 26)):
    f = font(BOLD, 22)
    w = int(d.textlength(text, font=f)) + 30
    d.rounded_rectangle([x, y, x + w, y + 36], radius=8, fill=bg)
    d.text((x + 15, y + 7), text, font=f, fill=colour)
    return y + 52


def block(d, x, y, arrow, colour, lines, typed=1.0, image=False, note=None,
          size=25):
    """One side of an exchange: an arrow, monospace text, an optional note."""
    d.text((x, y), arrow, font=font(BOLD, 32), fill=colour)
    tx = x + 46
    if image:
        d.rounded_rectangle([tx, y - 2, tx + 116, y + 62], radius=8,
                            fill=(30, 40, 58), outline=colour, width=2)
        d.text((tx + 12, y + 18), "screen", font=font(BOLD, 22), fill=colour)
        tx += 136
    f = font(MONO, size)
    budget = int(sum(len(s) for s in lines) * typed)
    yy = y
    for s in lines:
        if budget <= 0:
            break
        d.text((tx, yy), s[:budget], font=f, fill=colour)
        budget -= len(s)
        yy += size + 9
    if note and typed > 0.9:
        d.text((tx, yy + 4), note, font=font(REG, 24), fill=FAINT)
        yy += 34
    return yy + 22


def prose(d, x, y, lines, size=32, colour=DIM, gap=44):
    for line in lines:
        d.text((x, y), line, font=font(REG, size), fill=colour)
        y += gap
    return y



# ----------------------------------------------------------- diagram pieces
def box(d, x, y, w, h, title, colour, fill=(15, 24, 42)):
    """A labelled box. The label sits on the border, like a schematic."""
    d.rounded_rectangle([x, y, x + w, y + h], radius=14, fill=fill,
                        outline=colour, width=3)
    f = font(BOLD, 22)
    tw = int(d.textlength(title, font=f))
    d.rectangle([x + 22, y - 12, x + 40 + tw, y + 14], fill=(11, 18, 32))
    d.text((x + 31, y - 10), title, font=f, fill=colour)


def arrow(d, x1, y, x2, colour, label=None):
    """A horizontal arrow, with an optional word riding on top of it."""
    d.line([(x1, y), (x2 - 14, y)], fill=colour, width=4)
    d.polygon([(x2, y), (x2 - 18, y - 10), (x2 - 18, y + 10)], fill=colour)
    if label:
        f = font(REG, 22)
        w = int(d.textlength(label, font=f))
        d.text(((x1 + x2) // 2 - w // 2, y - 34), label, font=f, fill=FAINT)


def thumb(im, d, path, x, y, h, mark=None):
    """A screenshot, optionally with the point the model returned marked on it."""
    from PIL import Image
    shot = Image.open(path)
    w = int(h * shot.width / shot.height)
    im.paste(shot.resize((w, h)), (x, y))
    d.rectangle([x, y, x + w, y + h], outline=(70, 82, 100), width=2)
    if mark:
        nx, ny = mark
        px, py = x + int(w * nx / 1000), y + int(h * ny / 1000)
        for r in (20, 12):
            d.ellipse([px - r, py - r, px + r, py + r], outline=GREEN, width=3)
        d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=GREEN)
    return w


# ------------------------------------------------------------------ 1. a turn
def turn(t, goal):
    im, d = explain_base("One turn, start to finish",
                         "The same three moves repeat for every step.",
                         "decode", goal, phase=t)
    y = chip(d, LEFT, TOP, "WHAT THE MODEL IS SENT", BLUE, (18, 30, 52))
    p = at(t, 0.3, 1.8)
    if p > 0:
        block(d, LEFT, y, "→", BLUE,
              demo_prompts.wrapped(demo_prompts.vendor_system_prompt(), 42)[:4] +
              ["", '"Point to the Battery row."'],
              typed=p, image=True,
              note="the image part goes first — text first breaks it")

    p = at(t, 2.4, 1.0)
    if p > 0:
        y2 = chip(d, RIGHT, TOP, "WHAT COMES BACK", GREEN)
        block(d, RIGHT, y2, "←", GREEN,
              ['[{"image_id": 0, "point_2d": [500, 899],',
               '  "label": "Battery"}]'], typed=p,
              note="illustrative values — one JSON object per match")

    p = at(t, 3.8, 1.0)
    if p > 0:
        y3 = chip(d, RIGHT, TOP + 240, "WHAT IS DONE WITH IT", ORANGE, (44, 30, 16))
        block(d, RIGHT, y3, "→", ORANGE,
              ["500 / 1000 × 1080  →  540 px",
               "899 / 1000 × 2400  → 2158 px",
               "dispatchGesture(540, 2158)"], typed=p)

    if at(t, 5.2, 0.8) > 0:
        prose(d, RIGHT, TOP + 500,
              ["Then the screen has changed, and the next turn",
               "starts over with a fresh screenshot."])
    return im, d


# ----------------------------------------------------------------- 2. fresh
def fresh(t, goal):
    im, d = explain_base("The model does not remember the last screen.",
                         None, "encode", goal, phase=t)
    if at(t, 0.3, 1.0) > 0:
        prose(d, LEFT, TOP, ["A new conversation per turn, closed after it."])

    rows = [("turn 1", "screenshot A", "coordinates for screen A"),
            ("turn 2", "screenshot B", "coordinates for screen B"),
            ("turn 3", "screenshot C", "coordinates for screen C")]
    for i, (name, inp, out) in enumerate(rows):
        p = at(t, 1.2 + i * 0.6, 0.6)
        if p <= 0:
            continue
        y = TOP + 120 + i * 140
        d.rounded_rectangle([LEFT, y, LEFT + COL_W, y + 116], radius=12,
                            fill=(15, 24, 42), outline=LINE, width=2)
        d.text((LEFT + 30, y + 18), name, font=font(BOLD, 30), fill=BLUE)
        d.text((LEFT + 190, y + 18), f"→  {inp}", font=font(MONO, 24), fill=DIM)
        if p > 0.5:
            d.text((LEFT + 190, y + 62), f"←  {out}", font=font(MONO, 24), fill=GREEN)

    p = at(t, 3.2, 1.0)
    if p > 0:
        d.text((RIGHT, TOP), "What carries over", font=font(BOLD, 42), fill=INK)
        prose(d, RIGHT, TOP + 70,
              ["a list the loop writes and pastes into the next prompt:"])
        if p > 0.6:
            d.rounded_rectangle([RIGHT, TOP + 180, RIGHT + COL_W, TOP + 330],
                                radius=12, fill=(15, 24, 42), outline=LINE, width=2)
            d.text((RIGHT + 28, TOP + 206), "What you have already done:",
                   font=font(MONO, 25), fill=DIM)
            d.text((RIGHT + 28, TOP + 246), "1. tapped Notifications",
                   font=font(MONO, 25), fill=GREEN)
            d.text((RIGHT + 28, TOP + 282), "2. tapped Notification history",
                   font=font(MONO, 25), fill=GREEN)
    return im, d


# ------------------------------------------------------------- 3. next screen
def nextscreen(t, goal):
    im, d = explain_base("Turn 2 — same question, new screen",
                         "Nothing about the prompt changed.", "decode", goal,
                         phase=t)
    p = at(t, 0.3, 1.4)
    if p > 0:
        block(d, LEFT, TOP, "→", BLUE,
              demo_prompts.wrapped(
                  demo_prompts.tap_loop_prompt("open the notification history"),
                  42)[:5], typed=p, image=True)
    p = at(t, 1.9, 1.0)
    if p > 0:
        y = block(d, RIGHT, TOP, "←", GREEN,
                  ['[{"point_2d": [500, 277],',
                   '  "label": "notification history"}]'], typed=p)
        if at(t, 3.0, 1.0) > 0:
            y = block(d, RIGHT, y + 20, "→", ORANGE, ["tap  540, 665"], typed=1.0)
            prose(d, RIGHT, y + 20,
                  ["The screen behind it opens Notification history,",
                   "and that is the goal reached."])
    if at(t, 4.4, 0.8) > 0:
        d.text((LEFT, BOTTOM - 90), "The loop does not know that yet.",
               font=font(BOLD, 40), fill=INK)
        d.text((LEFT, BOTTOM - 34), "It will ask once more.",
               font=font(REG, 32), fill=DIM)
    return im, d


# ---------------------------------------------------------------- 4. anyway
def anyway(t, goal):
    im, d = explain_base("Turn 3 — it answers anyway",
                         "This is the behaviour the loop is built around.",
                         "decode", goal, phase=t)
    p = at(t, 0.3, 1.2)
    if p > 0:
        y = block(d, LEFT, TOP, "→", BLUE,
                  ['… "Return [] if the goal is already reached,',
                   '   or if nothing on this screen helps."'],
                  typed=p, image=True)
        if at(t, 1.7, 1.0) > 0:
            block(d, LEFT, y, "←", ORANGE,
                  ['[{"point_2d": [866, 167],',
                   '  "label": "open the notification history"}]'],
                  typed=1.0, note="from this run — the goal was already met")

    if at(t, 3.0, 1.0) > 0:
        d.text((LEFT, BOTTOM - 120), "It was told it could return [] and it did not.",
               font=font(BOLD, 38), fill=INK)
        prose(d, LEFT, BOTTOM - 66,
              ["So the loop stops on evidence instead: it taps,",
               "takes another screenshot, and compares."], size=30, gap=38)

    p = at(t, 4.0, 1.0)
    if p > 0:
        for i, x in enumerate((RIGHT, RIGHT + 260)):
            d.rounded_rectangle([x, TOP, x + 200, TOP + 420], radius=12,
                                fill=(22, 30, 44), outline=(52, 62, 80), width=3)
            for r in range(5):
                d.rounded_rectangle([x + 16, TOP + 30 + r * 76, x + 184, TOP + 84 + r * 76],
                                    radius=8, fill=(32, 42, 58))
        d.text((RIGHT, TOP + 436), "before the tap", font=font(REG, 26), fill=DIM)
        d.text((RIGHT + 260, TOP + 436), "after the tap", font=font(REG, 26), fill=DIM)
        if p > 0.6:
            d.text((RIGHT + 520, TOP + 160), "identical", font=font(BOLD, 38), fill=GREEN)
            d.text((RIGHT + 520, TOP + 212), "→ stop", font=font(BOLD, 38), fill=GREEN)
            d.text((RIGHT, TOP + 500), "32 × 64 thumbnails, mean brightness difference.",
                   font=font(REG, 26), fill=DIM)
            d.text((RIGHT, TOP + 538), "A tap that changes nothing ends the run.",
                   font=font(REG, 26), fill=DIM)
    return im, d


# ------------------------------------------------------- 5. the whole prompt
def plan_prompt_full(t, goal):
    """The whole planner prompt, as the app sends it, in two columns."""
    im, d = explain_base("This is what the app sends, word for word.",
                         None, "decode", goal, phase=t)
    text = demo_prompts.planner_prompt("search settings for wifi", [])
    lines = demo_prompts.wrapped(text, 58)
    half = (len(lines) + 1) // 2
    p = at(t, 0.3, 3.6)
    shown = int(len(lines) * p)
    f = font(MONO, 24)
    for i, line in enumerate(lines[:shown]):
        col_x = LEFT if i < half else RIGHT
        y = TOP + 20 + (i if i < half else i - half) * 33
        colour = GREEN if line.startswith("{") else DIM
        if line.startswith("Goal:") or line.startswith("What you have"):
            colour = INK
        d.text((col_x, y), line, font=f, fill=colour)
    if p > 0.99:
        d.text((LEFT, BOTTOM + 10), "The screenshot goes in front of all of this.",
               font=font(REG, 30), fill=FAINT)
    return im, d


# --------------------------------------------------------- step trace cards
def _thumb(d, im, path, x, y, h):
    from PIL import Image
    shot = Image.open(path)
    w = int(h * shot.width / shot.height)
    im.paste(shot.resize((w, h)), (x, y))
    d.rounded_rectangle([x - 4, y - 4, x + w + 4, y + h + 4], radius=10,
                        outline=(88, 100, 120), width=4)
    return w


def step_trace(t, goal, spec):
    """One step of a real run: the image sent, the prompts, the replies."""
    im, d = explain_base(spec["title"], spec["sub"], spec["stage"], goal, phase=t)
    chip(d, LEFT, TOP - 46, spec["chip"], BLUE, (18, 30, 52))

    thumb_h = 560
    thumb_w = _thumb(d, im, spec["shot"], LEFT, TOP, thumb_h)
    d.text((LEFT, TOP + thumb_h + 18), "what the model was sent",
           font=font(REG, 24), fill=FAINT)

    x = LEFT + thumb_w + 60
    column = W - x - 60
    longest = max((s for _, _, ls, _ in spec["exchange"] for s in ls), key=len,
                  default="")
    size = 25
    while size > 16 and d.textlength(longest, font=font(MONO, size)) > column:
        size -= 1

    y = TOP
    for i, (arrow, colour, lines, note) in enumerate(spec["exchange"]):
        p = at(t, 0.4 + i * 1.1, 0.9)
        if p <= 0:
            break
        y = block(d, x, y, arrow, colour, lines, typed=p, note=note, size=size)

    if spec.get("footer") and at(t, 0.4 + len(spec["exchange"]) * 1.1, 0.8) > 0:
        for j, line in enumerate(spec["footer"]):
            d.text((LEFT, BOTTOM + 4 + j * 40), line, font=font(REG, 30), fill=DIM)
    return im, d


def STEP1_SPEC():
    return {
        "title": "A logged run: 34 s for the first answer.",
        "sub": None,
        "stage": "decode", "chip": "STEP 1 OF 2",
        "shot": f"{os.path.dirname(os.path.dirname(os.path.abspath(__file__)))}/demo/frames/step1.png",
        "exchange": [
            ("→", BLUE,
             ["PLAN — our prompt", ""] +
             demo_prompts.wrapped(
                 demo_prompts.planner_prompt("search settings for wifi", []), 52)[:6] +
             ["…"],
             "sent with the screenshot on the left"),
            ("←", GREEN,
             ['{"action": "type", "target": "search box", "text": "wifi"}'],
             "logged at 14:46:28"),
            ("→", BLUE,
             ["GROUND — the vendor prompt, verbatim", ""] +
             demo_prompts.wrapped(demo_prompts.vendor_system_prompt(), 52)[:3] +
             ["…", '   "search box"'],
             "same screenshot, second question"),
            ("←", GREEN,
             ['[{"point_2d": [500, 96], "label": "search box"}]'],
             "logged at 14:46:39 — 11 s later"),
            ("→", ORANGE, ['tap 540, 230  →  set text "wifi"'],
             "the loop focuses the field, then types"),
        ],
    }


def STEP2_SPEC():
    return {
        "title": "New screenshot, so a new answer.",
        "sub": None,
        "stage": "decode", "chip": "STEP 2 OF 2",
        "shot": f"{os.path.dirname(os.path.dirname(os.path.abspath(__file__)))}/demo/frames/step2.png",
        "exchange": [
            ("→", BLUE,
             ["PLAN — our prompt, rewritten", "",
              "  Goal: search settings for wifi",
              "  What you have already done:",
              '  1. typed "wifi" into search box'],
             "the only memory that carries over"),
            ("←", GREEN, ['{"action": "done"}'], "logged at 14:46:58"),
            ("→", ORANGE, ["stop"], "no grounding call: nothing to locate"),
        ],
        "footer": ["Three model calls in all, for two steps.",
                   "Two of them needed a coordinate; one did not."],
    }



# ------------------------------------------------------ the mechanism itself
def _shot_with_point(d, im, path, x, y, h, nx, ny, label):
    """The screenshot the model was given, with the point it answered marked."""
    from PIL import Image
    shot = Image.open(path)
    w = int(h * shot.width / shot.height)
    im.paste(shot.resize((w, h)), (x, y))
    d.rounded_rectangle([x - 4, y - 4, x + w + 4, y + h + 4], radius=10,
                        outline=(88, 100, 120), width=4)
    px = x + int(w * nx / 1000)
    py = y + int(h * ny / 1000)
    d.line([(x, py), (x + w, py)], fill=(61, 220, 132, 120), width=2)
    d.line([(px, y), (px, y + h)], fill=(61, 220, 132, 120), width=2)
    for r in (26, 16):
        d.ellipse([px - r, py - r, px + r, py + r], outline=GREEN, width=4)
    d.ellipse([px - 4, py - 4, px + 4, py + 4], fill=GREEN)
    d.text((x, y + h + 14), label, font=font(REG, 24), fill=FAINT)
    return w


def mechanism(t, goal):
    """Screenshot and prompt in, coordinates out.

    Four boxes. An earlier cut had five, with the prompt in a box of its own —
    but the model is handed the picture and the words together, so a prompt on
    its own is a stage that does not exist.
    """
    im, d = explain_base("A screenshot goes in. Coordinates come out.", None,
                         "decode", goal, phase=t)
    shot = f"{os.path.dirname(os.path.dirname(os.path.abspath(__file__)))}/demo/frames/step1.png"
    by, bh = 300, 560
    xs = [70, 680, 1090, 1470]
    ws = [560, 360, 330, 380]
    mid = by + bh // 2

    if at(t, 0.2, 0.8) > 0:
        box(d, xs[0], by, ws[0], bh, "SENT TOGETHER", (150, 160, 176))
        thumb(im, d, shot, xs[0] + 24, by + 34, 400)
        tx = xs[0] + 224
        for i, line in enumerate(demo_prompts.wrapped(
                demo_prompts.vendor_system_prompt(), 25)[:9]):
            d.text((tx, by + 40 + i * 30), line, font=font(MONO, 19), fill=BLUE)
        d.text((tx, by + 356), '"Point to the search box."', font=font(MONO, 20),
               fill=INK)

    if at(t, 1.4, 0.6) > 0:
        arrow(d, xs[0] + ws[0] + 10, mid, xs[1] - 10, (90, 100, 120))
        box(d, xs[1], by, ws[1], bh, "MODEL", (150, 160, 176))
        from demo_robot import draw_robot
        draw_robot(d, xs[1] + ws[1] // 2, by + 180, 220, "thinking", phase=t)
        d.text((xs[1] + 26, by + 360), "LFM2.5-VL-3B int4", font=font(BOLD, 28), fill=INK)
        d.text((xs[1] + 26, by + 404), "on the phone, 11 s", font=font(REG, 26), fill=DIM)

    if at(t, 2.4, 0.8) > 0:
        arrow(d, xs[1] + ws[1] + 10, mid, xs[2] - 10, GREEN)
        box(d, xs[2], by, ws[2], bh, "ANSWER", GREEN)
        for i, line in enumerate(['[{', '  "image_id": 0,',
                                  '  "point_2d": [500, 96],',
                                  '  "label": "search box"', '}]']):
            d.text((xs[2] + 20, by + 44 + i * 34), line, font=font(MONO, 21), fill=GREEN)
        d.text((xs[2] + 20, by + 280), "0–1000,", font=font(BOLD, 30), fill=INK)
        d.text((xs[2] + 20, by + 320), "not pixels", font=font(BOLD, 30), fill=INK)

    if at(t, 3.4, 0.8) > 0:
        arrow(d, xs[2] + ws[2] + 10, mid, xs[3] - 10, ORANGE)
        box(d, xs[3], by, ws[3], bh, "PRESS", ORANGE)
        d.text((xs[3] + 20, by + 40), "500/1000 × 1080 = 540", font=font(MONO, 20),
               fill=ORANGE)
        d.text((xs[3] + 20, by + 68), " 96/1000 × 2400 = 230", font=font(MONO, 20),
               fill=ORANGE)
        thumb(im, d, shot, xs[3] + 105, by + 110, 380, mark=(500, 96))
        d.text((xs[3] + 20, by + 512), "dispatchGesture(540, 230)",
               font=font(MONO, 20), fill=ORANGE)

    return im, d


def notatree(t, goal):
    """The two ways of finding a button, drawn side by side."""
    im, d = explain_base("One way needs the app's ids. The other needs a screenshot.",
                         None, "capture", goal, phase=t)
    shot = f"{os.path.dirname(os.path.dirname(os.path.abspath(__file__)))}/demo/frames/step1.png"

    # the usual way: read the view tree, match a selector
    if at(t, 0.2, 0.8) > 0:
        d.text((90, 320), "the usual way", font=font(BOLD, 32), fill=(255, 140, 120))
        nodes = [(120, 380, "DecorView"), (200, 452, "RecyclerView"),
                 (280, 524, "ViewGroup"), (360, 596, 'TextView  id/title')]
        prev = None
        for i, (x, y, label) in enumerate(nodes):
            if at(t, 0.4 + i * 0.25, 0.4) <= 0:
                break
            d.rounded_rectangle([x, y, x + 300, y + 46], radius=8,
                                fill=(26, 22, 30), outline=(120, 92, 96), width=2)
            d.text((x + 16, y + 10), label, font=font(MONO, 20), fill=(226, 176, 170))
            if prev:
                d.line([(prev[0] + 24, prev[1] + 46), (prev[0] + 24, y + 23),
                        (x, y + 23)], fill=(120, 92, 96), width=2)
            prev = (x, y)
        if at(t, 1.6, 0.6) > 0:
            d.text((120, 680), 'findViewById(R.id.title).performClick()',
                   font=font(MONO, 22), fill=(226, 176, 170))
            d.line([(110, 370), (500, 720)], fill=(255, 90, 84), width=6)
            d.line([(500, 370), (110, 720)], fill=(255, 90, 84), width=6)
            d.text((90, 754), "needs ids, and an app that exposes them",
                   font=font(REG, 26), fill=DIM)

    # this way: look at the picture, answer with a position
    if at(t, 2.6, 0.8) > 0:
        d.text((1020, 320), "this way", font=font(BOLD, 32), fill=GREEN)
        thumb(im, d, shot, 1020, 370, 380, mark=(500, 96) if at(t, 3.6, 0.6) > 0.5 else None)
        arrow(d, 1210, 560, 1360, GREEN)
        d.rounded_rectangle([1380, 470, 1810, 660], radius=14, fill=(15, 24, 42),
                            outline=GREEN, width=3)
        d.text((1404, 500), '{"point_2d":', font=font(MONO, 24), fill=GREEN)
        d.text((1404, 536), '  [500, 96]}', font=font(MONO, 24), fill=GREEN)
        d.text((1404, 590), "→ 540, 230 px", font=font(MONO, 24), fill=ORANGE)
        if at(t, 4.2, 0.6) > 0:
            d.text((1020, 780), "needs a screenshot", font=font(REG, 26), fill=DIM)

    if at(t, 5.0, 0.8) > 0:
        d.text((90, BOTTOM - 60), "One inference per step is the price.",
               font=font(BOLD, 32), fill=INK)
    return im, d


def stoprule(t, goal):
    """The loop, drawn as a loop, with the exit that actually fires."""
    im, d = explain_base("It stops when the screen stops changing.",
                         None, "capture", goal, phase=t)
    steps = [("capture", "one screenshot", 660, 330),
             ("ask", "prompt → coordinates", 1080, 330),
             ("press", "540, 230", 1500, 330),
             ("compare", "before vs after", 1080, 640)]
    colours = {"capture": (150, 160, 176), "ask": BLUE, "press": ORANGE,
               "compare": GREEN}
    for i, (name, note, x, y) in enumerate(steps):
        if at(t, 0.2 + i * 0.5, 0.5) <= 0:
            break
        c = colours[name]
        d.rounded_rectangle([x, y, x + 300, y + 120], radius=14, fill=(15, 24, 42),
                            outline=c, width=3)
        d.text((x + 20, y + 24), name, font=font(BOLD, 30), fill=c)
        d.text((x + 20, y + 68), note, font=font(MONO, 20), fill=DIM)

    if at(t, 0.8, 0.5) > 0:
        arrow(d, 968, 390, 1070, (90, 100, 120))
    if at(t, 1.3, 0.5) > 0:
        arrow(d, 1388, 390, 1490, (90, 100, 120))
    if at(t, 1.8, 0.5) > 0:
        d.line([(1650, 450), (1650, 700), (1390, 700)], fill=(90, 100, 120), width=4)
        d.polygon([(1380, 700), (1398, 690), (1398, 710)], fill=(90, 100, 120))
    if at(t, 2.4, 0.6) > 0:
        d.line([(1080, 700), (810, 700), (810, 450)], fill=GREEN, width=4)
        d.polygon([(810, 440), (800, 458), (820, 458)], fill=GREEN)
        d.text((690, 712), "changed → go again", font=font(BOLD, 26), fill=GREEN)

    if at(t, 3.0, 0.8) > 0:
        d.line([(1230, 760), (1230, 840)], fill=(255, 90, 84), width=4)
        d.polygon([(1230, 852), (1220, 834), (1240, 834)], fill=(255, 90, 84))
        d.text((1080, 862), "identical → stop", font=font(BOLD, 30), fill=(255, 90, 84))

    if at(t, 3.8, 0.8) > 0:
        d.rounded_rectangle([70, 400, 590, 700], radius=14, fill=(26, 22, 30),
                            outline=(120, 92, 96), width=2)
        d.text((96, 428), "why not just ask the model?", font=font(BOLD, 28),
               fill=(226, 176, 170))
        d.text((96, 486), '← [{"point_2d": [866, 167],', font=font(MONO, 20),
               fill=(226, 176, 170))
        d.text((96, 514), '     "label": "open the', font=font(MONO, 20),
               fill=(226, 176, 170))
        d.text((96, 542), '      notification history"}]', font=font(MONO, 20),
               fill=(226, 176, 170))
        d.text((96, 596), "the goal was already met, and it", font=font(REG, 22),
               fill=DIM)
        d.text((96, 624), "invented a target instead of []", font=font(REG, 22), fill=DIM)
    return im, d



BEATS = {
    "mechanism": mechanism, "notatree": notatree, "stoprule": stoprule,
    "turn": turn, "fresh": fresh, "nextscreen": nextscreen, "anyway": anyway,
    "planprompt": plan_prompt_full,
    "step1": lambda t, g: step_trace(t, g, STEP1_SPEC()),
    "step2": lambda t, g: step_trace(t, g, STEP2_SPEC()),
}


def render(name, out_dir, seconds, real_seconds, goal):
    fn = BEATS[name]
    os.makedirs(out_dir, exist_ok=True)
    frames = int(seconds * FPS)
    for i in range(frames):
        t = i / FPS
        im, d = fn(t, goal)
        waited(d, real_seconds * min(1.0, t / seconds), real_seconds, seconds)
        im.save(f"{out_dir}/{i:05d}.png")
    return frames
