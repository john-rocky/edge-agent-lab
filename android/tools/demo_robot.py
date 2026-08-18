#!/usr/bin/env python3
"""The agent's face, drawn once here so the phone and the video agree.

Read at 72dp on a phone, so silhouette does the work: antenna, ears, a square
head and two eyes. One eye looked like a lens; two look like somebody.
"""
import math
from PIL import Image, ImageDraw

SLATE = (42, 52, 68)
SLATE_EDGE = (86, 102, 128)
PLATE = (10, 14, 20)
GREY = (152, 162, 176)
BLUE = (108, 166, 255)
GREEN = (61, 220, 132)
ORANGE = (255, 176, 102)

TINTS = {
    "idle": GREY, "looking": BLUE, "thinking": BLUE,
    "acting": GREEN, "done": GREEN, "stopped": ORANGE,
}


def draw_robot(d, cx, cy, size, state="looking", aim=(0.0, 0.0), phase=0.0,
               blink=1.0):
    """`size` is the full height the robot occupies, antenna included."""
    tint = TINTS[state]
    s = size
    head_w, head_h = s * 0.74, s * 0.62
    hx0, hy0 = cx - head_w / 2, cy - head_h / 2 + s * 0.06
    hx1, hy1 = hx0 + head_w, hy0 + head_h
    r = s * 0.20

    # antenna: stalk, then a ball that pulses only while a call is in flight
    pulse = (math.sin(phase * 4.2) * 0.5 + 0.5) if state == "thinking" else 0.0
    ball_r = s * 0.055 + s * 0.018 * pulse
    top = hy0 - s * 0.10
    d.line([(cx, top), (cx, hy0 + 2)], fill=SLATE_EDGE, width=max(2, int(s * 0.028)))
    d.ellipse([cx - ball_r, top - ball_r, cx + ball_r, top + ball_r], fill=tint)

    # ears
    ear_w, ear_h = s * 0.07, s * 0.22
    for ex in (hx0 - ear_w * 0.75, hx1 - ear_w * 0.25):
        d.rounded_rectangle([ex, cy - ear_h / 2 + s * 0.05, ex + ear_w,
                             cy + ear_h / 2 + s * 0.05],
                            radius=ear_w / 2, fill=SLATE_EDGE)

    # head and the darker face plate inside it
    d.rounded_rectangle([hx0, hy0, hx1, hy1], radius=r, fill=SLATE,
                        outline=SLATE_EDGE, width=max(2, int(s * 0.02)))
    inset = s * 0.06
    d.rounded_rectangle([hx0 + inset, hy0 + inset, hx1 - inset, hy1 - inset],
                        radius=r * 0.72, fill=PLATE)

    # eyes
    eye_dx = head_w * 0.20
    eye_y = hy0 + head_h * 0.42
    eye_r = s * 0.082
    ax = max(-1.0, min(1.0, aim[0] * 2)) * eye_r * 0.42
    ay = max(-1.0, min(1.0, aim[1] * 2)) * eye_r * 0.42

    for ex in (cx - eye_dx, cx + eye_dx):
        if state == "done":                      # happy arcs
            d.arc([ex - eye_r, eye_y - eye_r, ex + eye_r, eye_y + eye_r * 0.8],
                  200, 340, fill=tint, width=max(3, int(s * 0.035)))
        elif state == "stopped" or blink < 0.25:  # shut
            d.line([(ex - eye_r * 0.9, eye_y), (ex + eye_r * 0.9, eye_y)],
                   fill=tint, width=max(3, int(s * 0.035)))
        elif state == "thinking":                 # narrowed
            d.rounded_rectangle([ex - eye_r, eye_y - eye_r * 0.42,
                                 ex + eye_r, eye_y + eye_r * 0.42],
                                radius=eye_r * 0.42, fill=tint)
        else:
            d.ellipse([ex - eye_r, eye_y - eye_r, ex + eye_r, eye_y + eye_r], fill=tint)
            pr = eye_r * 0.42
            d.ellipse([ex + ax - pr, eye_y + ay - pr, ex + ax + pr, eye_y + ay + pr],
                      fill=PLATE)

    # mouth
    my = hy0 + head_h * 0.74
    if state == "done":
        d.arc([cx - s * 0.10, my - s * 0.06, cx + s * 0.10, my + s * 0.06],
              20, 160, fill=tint, width=max(2, int(s * 0.025)))
    elif state == "thinking":
        for i in range(3):
            on = (int(phase * 3) % 3) == i
            rr = s * 0.018 * (1.6 if on else 1.0)
            d.ellipse([cx - s * 0.07 + i * s * 0.07 - rr, my - rr,
                       cx - s * 0.07 + i * s * 0.07 + rr, my + rr],
                      fill=tint if on else SLATE_EDGE)
    else:
        d.line([(cx - s * 0.075, my), (cx + s * 0.075, my)],
               fill=SLATE_EDGE, width=max(2, int(s * 0.022)))

    # a ring leaving the head at the moment it presses
    if state == "acting":
        t = (phase * 1.6) % 1.0
        rad = head_w * 0.6 + s * 0.28 * t
        fade = int(255 * (1 - t))
        d.ellipse([cx - rad, cy - rad + s * 0.06, cx + rad, cy + rad + s * 0.06],
                  outline=tint + (fade,), width=max(2, int(s * 0.03 * (1 - t)) + 1))


def sheet(path, size=150):
    states = ["idle", "looking", "thinking", "acting", "done", "stopped"]
    w = size * len(states) + 40 * (len(states) + 1)
    im = Image.new("RGBA", (w, size + 120), (255, 255, 255, 255))
    d = ImageDraw.Draw(im, "RGBA")
    for i, st in enumerate(states):
        cx = 40 + size / 2 + i * (size + 40)
        draw_robot(d, cx, size / 2 + 40, size, st, aim=(0.3, 0.2), phase=0.4)
        d.text((cx - 26, size + 70), st, fill=(60, 68, 80))
    im.save(path)


if __name__ == "__main__":
    import sys
    sheet(sys.argv[1] if len(sys.argv) > 1 else "robot_sheet.png")
    print("sheet written")
