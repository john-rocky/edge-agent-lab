#!/usr/bin/env python3
"""Shared furniture for the demo, laid out for a 16:9 frame.

The demo was portrait first, which forced everything into one column: phone,
then caption, then explanation, each waiting its turn. Landscape lets the phone
and the words about it sit side by side, which is what the material wants —
you watch the screen change while you read why.

Two visual worlds, kept apart on purpose: footage from the device always sits in
a bezel on grey with a red dot, an explainer is always full-bleed on blue. Both
carry the same five-stage rail.
"""
from PIL import Image, ImageDraw, ImageFont

W, H = 1920, 1080

DEVICE_BG = (20, 24, 32)
EXPLAIN_BG = (11, 18, 32)
INK = (255, 255, 255)
DIM = (143, 152, 163)
FAINT = (74, 84, 96)
LINE = (44, 50, 58)
GREEN = (61, 220, 132)
BLUE = (108, 166, 255)
RED = (255, 90, 84)

BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
MONO = "/System/Library/Fonts/Menlo.ttc"   # replaced wholesale for other languages

# The phone, dead centre and as large as the frame allows. Earlier cuts put it
# small in a corner with a magnified strip beside it; the strip was impossible
# to place in the whole, and the screen is the evidence. So: one view, centred,
# 1000 px tall, and the words go beside it.
VID_H = 1000
VID_W = int(VID_H * 1080 / 2400)          # 450
VID_X, VID_Y = (W - VID_W) // 2, 40

BAR = 72          # goal bar
RAIL_Y = 92       # state rail sits just under it
BODY_Y = 170      # everything else starts here
TEXT_X = 620      # the right-hand column, beside the phone
CAPTION_Y = 900   # captions run along the bottom of the right column

STAGES = ["capture", "frame", "encode", "decode", "act"]


def font(path, size):
    """Resolve at call time so a language switch can replace the faces."""
    import demo_chrome as self_module
    if path == "/System/Library/Fonts/Supplemental/Arial Bold.ttf":
        path = self_module.BOLD
    elif path == "/System/Library/Fonts/Supplemental/Arial.ttf":
        path = self_module.REG
    elif path == "/System/Library/Fonts/Menlo.ttc":
        path = self_module.MONO
    return ImageFont.truetype(path, size)


def fitted(d, text, path, size, max_width):
    while size > 18:
        f = font(path, size)
        if d.textlength(text, font=f) <= max_width:
            return f
        size -= 2
    return font(path, size)


def wrap(d, text, f, max_width):
    words, lines, line = text.split(" "), [], ""
    for word in words:
        probe = f"{line} {word}".strip()
        if d.textlength(probe, font=f) <= max_width or not line:
            line = probe
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def block_text(d, x, y, text, path, size, max_width, fill, gap=12):
    """Wrap at a readable size, and only shrink if a line still will not fit.

    `fitted` alone shrinks the whole caption until it is one line, which turned
    a long sentence into small print. Wrapping first keeps the type big.
    """
    f = font(path, size)
    while size > 22:
        lines = wrap(d, text, f, max_width)
        if all(d.textlength(line, font=f) <= max_width for line in lines):
            break
        size -= 2
        f = font(path, size)
    for line in wrap(d, text, f, max_width):
        d.text((x, y), line, font=f, fill=fill)
        y += f.size + gap
    return y


def goal_bar(d, goal):
    d.rectangle([0, 0, W, BAR], fill=(8, 10, 13))
    if goal:
        d.text((60, 18), goal, font=fitted(d, goal, REG, 34, W - 120), fill=DIM)


def rail(d, current, y=RAIL_Y):
    """capture · frame · encode · decode · act, with one lit (None = none yet)."""
    x = 60
    f = font(BOLD, 24)
    for i, name in enumerate(STAGES):
        on = name == current
        col = GREEN if on else FAINT
        d.ellipse([x, y + 8, x + 13, y + 21], fill=col if on else LINE,
                  outline=col, width=2)
        d.text((x + 24, y + 3), name, font=f, fill=col)
        x += 24 + int(d.textlength(name, font=f)) + 28
        if i < len(STAGES) - 1:
            d.line([(x - 16, y + 14), (x - 6, y + 14)], fill=LINE, width=2)


def caption(d, main, sub=None, x=TEXT_X, y=CAPTION_Y):
    """The line that says what just happened, beside the phone rather than under
    it — in landscape the screen is tall and the words have room to its right."""
    fm = fitted(d, main, BOLD, 46, W - x - 60)
    d.text((x, y), main, font=fm, fill=INK)
    if sub:
        fs = fitted(d, sub, REG, 34, W - x - 60)
        d.text((x, y + 62), sub, font=fs, fill=DIM)


def device_overlay(path, goal, stage, main, sub=None, live=True):
    """Transparent layer for footage: one big centred screen, words either side."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    goal_bar(d, goal)
    rail(d, stage, y=H - 52)
    d.rounded_rectangle([VID_X - 8, VID_Y - 8, VID_X + VID_W + 8, VID_Y + VID_H + 8],
                        radius=24, outline=(58, 66, 78), width=4)
    if live:
        d.ellipse([VID_X - 220, VID_Y + 10, VID_X - 198, VID_Y + 32], fill=RED)
        d.text((VID_X - 186, VID_Y + 8), "REAL TIME", font=font(BOLD, 24), fill=RED)

    # the sentence about what just happened, in the space to the left
    box = VID_X - 120
    y = block_text(d, 60, H // 2 - 120, main, BOLD, 46, box, INK)
    if sub:
        block_text(d, 60, y + 16, sub, REG, 32, box, DIM, gap=8)
    im.save(path)
    return path


def montage_overlay(path, main, goal, label, sub=None):
    """The opening cut: the phone working, and the order it was given.

    No goal bar and no rail. Neither has been explained yet at this point in the
    video, and this stretch is meant to be watched rather than read. The goal
    itself is quoted as it was typed, in English, in both language cuts.
    """
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([VID_X - 8, VID_Y - 8, VID_X + VID_W + 8, VID_Y + VID_H + 8],
                        radius=24, outline=(58, 66, 78), width=4)
    d.ellipse([VID_X - 200, VID_Y + 10, VID_X - 178, VID_Y + 32], fill=RED)
    d.text((VID_X - 166, VID_Y + 8), "ON DEVICE", font=font(BOLD, 24), fill=RED)

    box = VID_X - 120
    y = block_text(d, 60, H // 2 - 200, main, BOLD, 52, box, INK)

    d.text((60, y + 26), label, font=font(BOLD, 24), fill=GREEN)
    fg = fitted(d, goal, BOLD, 34, box - 56)
    lines = wrap(d, goal, fg, box - 56)
    top = y + 62
    height = 28 + len(lines) * (fg.size + 10)
    d.rounded_rectangle([60, top, 60 + box, top + height], radius=12,
                        outline=GREEN, width=3)
    ty = top + 14
    for line in lines:
        d.text((88, ty), line, font=fg, fill=INK)
        ty += fg.size + 10

    if sub:
        block_text(d, 60, top + height + 30, sub, REG, 30, box, DIM, gap=8)
    im.save(path)
    return path


SCALE = VID_W / 1080
FIELD = (VID_X + int(24 * SCALE), VID_Y + int(2180 * SCALE),
         VID_X + int(1056 * SCALE), VID_Y + int(2318 * SCALE))


def instruction_overlay(path, goal, main, sub=None):
    """The moment a human gives the order. Same centred screen as everywhere
    else — the app's own reply is quoted beside it rather than magnified, since
    a crop of a screenshot inside a screenshot is a puzzle, not an aid."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    goal_bar(d, goal)
    rail(d, None, y=H - 52)
    d.rounded_rectangle([VID_X - 8, VID_Y - 8, VID_X + VID_W + 8, VID_Y + VID_H + 8],
                        radius=24, outline=(58, 66, 78), width=4)
    x0, y0, x1, y1 = FIELD
    d.rounded_rectangle([x0 - 6, y0 - 6, x1 + 6, y1 + 6], radius=10, outline=GREEN, width=4)
    d.text((VID_X, y0 - 44), "type a goal, press Run", font=font(BOLD, 26), fill=GREEN)

    box = VID_X - 120
    y = block_text(d, 60, H // 2 - 140, main, BOLD, 46, box, INK)
    if sub:
        block_text(d, 60, y + 16, sub, REG, 32, box, DIM, gap=8)
    im.save(path)
    return path


def explain_base(title, sub, stage, goal, phase=0.0):
    """Full-bleed blue canvas for a diagram, with the same rail.

    No chrome beyond the goal, the rail and the title: the diagram is the point,
    and a mascot in the corner of an explanation is one more thing to look at
    that means nothing.
    """
    im = Image.new("RGB", (W, H), EXPLAIN_BG)
    d = ImageDraw.Draw(im)
    for gx in range(0, W, 60):
        d.line([(gx, BAR), (gx, H)], fill=(16, 24, 40), width=1)
    for gy in range(BAR, H, 60):
        d.line([(0, gy), (W, gy)], fill=(16, 24, 40), width=1)
    goal_bar(d, goal)
    rail(d, stage)

    d.text((60, 150), title, font=fitted(d, title, BOLD, 58, W - 120), fill=INK)
    if sub:
        d.text((60, 224), sub, font=fitted(d, sub, REG, 36, W - 120), fill=DIM)
    return im, d


def waited(d, elapsed, real_total, shown_over):
    """The wait, counted out loud, with the speed-up stated."""
    factor = real_total / shown_over if shown_over else 1
    y = H - 110
    d.rectangle([0, y - 30, W, H], fill=(8, 10, 13))
    d.text((60, y - 14), f"{elapsed:0.1f} s", font=font(BOLD, 46), fill=GREEN)
    d.text((210, y - 4),
           f"the phone is still working — {real_total:0.0f} s in all, shown at ×{factor:0.0f}",
           font=font(REG, 30), fill=DIM)
    width = int((W - 120) * min(1.0, elapsed / real_total if real_total else 0))
    d.rounded_rectangle([60, H - 42, W - 60, H - 32], radius=5, fill=(30, 34, 40))
    if width > 12:
        d.rounded_rectangle([60, H - 42, 60 + width, H - 32], radius=5, fill=GREEN)
