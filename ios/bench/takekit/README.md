# takekit — record a take without recording the screen

Window-layer capture: `screencapture -l <windowid>` shoots the app's own
layer, even occluded, so nothing else on the display can enter the frame
(docs/demo-playbook.md: never record the user's display). All scripts run
with `xcrun swift <script>`.

- `windowrect.swift` — prints `x y w h windowid` for the LFMTools window.
- `concat.swift <a.mp4> <secA> <b.mp4> <secB> <out.mp4>` — two clips into
  one 1280×720 aspect-filled video (take footage prep; silent output).
- `assemble.swift <framesDir> <out.mp4> <fps>` — a frame sequence into an
  mp4 (2 fps ≈ real time for a 0.5 s capture cadence).

The take loop (from a shell, app launched via `open -n <app> --args …` —
TCC blames the parent shell for a naked binary):

    WID=$(xcrun swift windowrect.swift | head -1 | awk '{print $5}')
    while …run not finished…; do
      screencapture -x -o -l$WID take/frame-$(printf %03d $N).png
      sleep 0.35
    done
    xcrun swift assemble.swift take out.mp4 2
