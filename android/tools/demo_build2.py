#!/usr/bin/env python3
"""Assemble the demo: phone footage and explainers, alternating.

Three rules, each one a fix for something a viewer tripped over:
  - footage from the device is always inside a bezel on grey, with a red dot;
    an explainer is always full-bleed on blue. Never the same look.
  - every wait carries the next idea. No gap is a frozen screen.
  - a five-stage rail is on every frame, so "what is it doing now" is always
    answered.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from PIL import Image, ImageDraw

import demo_beats as beats
import demo_chrome as chrome

if os.environ.get("DEMO_LANG") == "ja":
    import demo_lang
    demo_lang.apply()
from demo_chrome import (W, H, VID_W, VID_H, VID_X, VID_Y, DEVICE_BG, BOLD, REG,
                    INK, DIM, GREEN, font, fitted,
)

LANG = os.environ.get("DEMO_LANG", "en")
SP = "/tmp/screen-agent-demo" + ("-ja" if LANG == "ja" else "")
REPO = os.path.dirname(HERE)
OUT = f"{SP}/build2"
FPS = 30

P2 = f"{REPO}/demo/phase2_battery.mp4"
P25 = f"{REPO}/demo/phase25_agent_loop.mp4"
ACT = f"{REPO}/demo/phase3_act_loop.mp4"
TRACE = f"{REPO}/demo/phase3_act_loop.mp4"
ROBOT = f"{REPO}/demo/agent_taps.mp4"

os.makedirs(OUT, exist_ok=True)
pieces = []


def run(args):
    subprocess.run(args, check=True, capture_output=True)


def card(idx, title, lines, seconds=2.6):
    png, mp4 = f"{OUT}/c{idx}.png", f"{OUT}/{idx:02d}_card.mp4"
    im = Image.new("RGB", (W, H), (13, 15, 18))
    d = ImageDraw.Draw(im)
    box = W - 400
    ft = min((fitted(d, part, BOLD, 92, box) for part in title), key=lambda f: f.size)
    y = H // 2 - 150
    d.rectangle([160, y - 40, 172, y + 60 + 112 * (len(title) - 1)], fill=GREEN)
    for i, part in enumerate(title):
        d.text((220, y + i * 112), part, font=ft, fill=INK)
    y += 112 * len(title) + 50
    for line in lines:
        d.text((220, y), line, font=fitted(d, line, REG, 42, box), fill=DIM)
        y += 62
    im.save(png)
    run(["ffmpeg", "-y", "-v", "error", "-loop", "1", "-t", str(seconds), "-i", png,
         "-vf", f"fps={FPS},format=yuv420p", "-c:v", "libx264", "-preset", "medium",
         "-crf", "23", mp4])
    pieces.append(mp4)


def device(idx, src, start, end, goal, stage, main, sub=None, band=None):
    """Footage: the screen, centred, as big as the frame allows."""
    png = chrome.device_overlay(f"{OUT}/d{idx}.png", goal, stage, main, sub)
    mp4 = f"{OUT}/{idx:02d}_dev.mp4"
    bg = f"0x{DEVICE_BG[0]:02x}{DEVICE_BG[1]:02x}{DEVICE_BG[2]:02x}"
    # setsar=1: a phone screenshot can carry a sample aspect ratio that is not
    # 1:1, and after padding the encoder then sees a display height of 1081 and
    # refuses it.
    vf = (f"[0:v]trim=start={start}:end={end},setpts=PTS-STARTPTS,fps={FPS},"
          f"scale={VID_W}:{VID_H},pad={W}:{H}:{VID_X}:{VID_Y}:color={bg},setsar=1[base];"
          f"[base][1:v]overlay=0:0,format=yuv420p")
    run(["ffmpeg", "-y", "-v", "error", "-i", src, "-i", png,
         "-filter_complex", vf, "-an", "-c:v", "libx264", "-preset", "medium",
         "-crf", "23", mp4])
    pieces.append(mp4)


def montage(cuts, main, sub=None):
    """The opening: only the seconds in which the phone changes.

    Every task in the video runs at 11–23 s per turn, so a cut that keeps the
    waits opens on a still frame. Here the waits are dropped and the presses run
    into each other; the caption says so, and the timed version follows.
    """
    bg = f"0x{DEVICE_BG[0]:02x}{DEVICE_BG[1]:02x}{DEVICE_BG[2]:02x}"
    for i, (src, start, end, goal) in enumerate(cuts):
        png = chrome.montage_overlay(f"{OUT}/m{i}.png", main, goal,
                                     "THE INSTRUCTION TYPED", sub)
        mp4 = f"{OUT}/00{i}_mont.mp4"
        # fps before trim, not after: screenrecord writes a frame only when the
        # screen changes (these files average 2.6 fps), so trimming first drops
        # the held frame and the cut starts wherever the next frame happens to
        # be — which is usually the change itself, with no run-up to it.
        vf = (f"[0:v]fps={FPS},trim=start={start}:end={end},setpts=PTS-STARTPTS,"
              f"scale={VID_W}:{VID_H},pad={W}:{H}:{VID_X}:{VID_Y}:color={bg},setsar=1[base];"
              f"[base][1:v]overlay=0:0,format=yuv420p")
        run(["ffmpeg", "-y", "-v", "error", "-i", src, "-i", png,
             "-filter_complex", vf, "-an", "-c:v", "libx264", "-preset", "medium",
             "-crf", "23", mp4])
        pieces.append(mp4)


def instruction(idx, still, goal, main, sub=None, seconds=4.2):
    """A held still of the app itself, so the order is seen being given.

    A screenshot rather than a frame of the run: the app grew a face after those
    recordings were made, and the shot has to show what the app looks like now.
    """
    png = chrome.instruction_overlay(f"{OUT}/io{idx}.png", goal, main, sub)
    mp4 = f"{OUT}/{idx:02d}_instr.mp4"
    bg = f"0x{DEVICE_BG[0]:02x}{DEVICE_BG[1]:02x}{DEVICE_BG[2]:02x}"
    vf = (f"[0:v]scale={VID_W}:{VID_H},pad={W}:{H}:{VID_X}:{VID_Y}:color={bg},setsar=1[base];"
          f"[base][1:v]overlay=0:0,format=yuv420p")
    run(["ffmpeg", "-y", "-v", "error", "-loop", "1", "-t", str(seconds), "-i", still,
         "-i", png, "-filter_complex", vf, "-r", str(FPS),
         "-c:v", "libx264", "-preset", "medium", "-crf", "23", mp4])
    pieces.append(mp4)


def beat(idx, name, seconds, real_seconds, goal):
    frames = f"{OUT}/b_{name}"
    mp4 = f"{OUT}/{idx:02d}_beat.mp4"
    if not os.path.isdir(frames) or not os.listdir(frames):
        beats.render(name, frames, seconds, real_seconds, goal)
    run(["ffmpeg", "-y", "-v", "error", "-framerate", str(FPS),
         "-i", f"{frames}/%05d.png", "-vf", "format=yuv420p",
         "-c:v", "libx264", "-preset", "medium", "-crf", "23", mp4])
    pieces.append(mp4)


G1 = 'Goal: "Point to the Battery row."'
G2 = 'Goal: "open the notification history"'
G3 = 'Goal: "search settings for wifi"'

# ------------------------------------------------ the opening, waits removed
# The screen changes at 13.9, 14.5, 28.6, 56.6/58.3 and 60.8 — measured by
# differencing the decoded frames, not eyeballed — and each cut opens about a
# second before its own change so the press is seen landing.
montage([(P2, 13.0, 15.2, "Point to the Battery row."),          # → Battery
         (P25, 13.6, 15.8, "open the notification history"),     # → Notifications
         (P25, 27.7, 29.9, "open the notification history"),     # → history
         (ACT, 55.8, 58.8, "search settings for wifi"),          # field, "wifi"
         (ACT, 60.0, 61.8, "search settings for wifi")],         # results
        "An agent is operating the phone",
        "Three tasks, back to back. The waits for inference are cut here; "
        "the rest of the video keeps them.")

card(1, ["An agent that operates an", "Android phone, built on", "LFM2.5-VL"],
     ["It works from a screenshot, on any app.",
      "3B int4 on a Pixel 8a. CPU only, no INTERNET permission."])

# ------------------------------------------------- the mechanism, up front
card(2, ["Task 1", "Tap the row I name"],
     ["Mode: Tap"])
instruction(21, f"{REPO}/demo/frames/app_tap.png", G1,
            "Name the row you want pressed",
            "It reads the name back, then steps behind what is on screen.")
beat(3, "mechanism", 13.0, 10.5, G1)
device(4, P2, 13.0, 16.6, G1, "act", "The coordinates become a press")
beat(5, "notatree", 10.5, 10.5, G1)

# ------------------------------------------------------- a goal, many turns
card(6, ["Task 2", "Get two screens deep"],
     ["Mode: Agent — it picks each tap"])
instruction(22, f"{REPO}/demo/frames/app_agent.png", G2,
            "Settings → Notifications → Notification history, unaided.")
beat(7, "fresh", 10.0, 11.5, G2)
device(8, P25, 13.8, 17.2, G2, "act", "1 · tapped Notifications",
       "Settings → Notifications")
device(9, P25, 27.8, 31.2, G2, "act", "2 · tapped Notification history",
       "Notifications → Notification history")
beat(10, "stoprule", 11.0, 62.5, G2)
device(11, P25, 96.0, 99.2, G2, "capture", "It stops: the screen did not change",
       "Three turns; the third moved nothing.")

# ------------------------------------------- two prompts, and the full text
card(12, ["Task 3", "Type into the search box"],
     ["Mode: Act — scroll, back and typing",
      "Every prompt and reply below is from this run's log."])
instruction(23, f"{REPO}/demo/frames/app_act.png", G3,
            "Say what to type, and where",
            "Scrolling and pressing are its own business.")
beat(25, "planprompt", 14.0, 37.5, G3)
beat(13, "step1", 14.5, 34.0, G3)
device(14, TRACE, 54.2, 57.8, G3, "act", 'typed "wifi" into the search box')
beat(15, "step2", 10.5, 19.0, G3)
device(16, TRACE, 62.0, 65.4, G3, "capture", 'the model answered {"action": "done"}',
       "Two steps, three model calls, 2 min 10 s.")

card(19, ["Every turn:", "screenshot → prompt → coordinates → press"],
     ["11–23 s per turn · 3B int4 · CPU only",
      "No GPU or NPU path yet: this is the floor, not the ceiling.",
      "Grounding, framing and the loop are a Kotlin library."], seconds=4.0)

with open(f"{OUT}/list.txt", "w") as fh:
    for p in pieces:
        fh.write(f"file '{p}'\n")
run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", f"{OUT}/list.txt",
     "-c:v", "libx264", "-preset", "medium", "-crf", "23", "-pix_fmt", "yuv420p",
     f"{SP}/demo_v3.mp4"])
dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                      "-of", "csv=p=0", f"{SP}/demo_v3.mp4"],
                     capture_output=True, text=True).stdout.strip()
print(f"{len(pieces)} pieces, {float(dur):.1f}s -> {SP}/demo_v3.mp4")
