#!/bin/zsh
# After the main driver: re-run every Apple FM run whose result file is missing
# (the first ones failed with "system model unavailable" while the phone's
# language was Japanese). Appends to driver.log; ends with APPLE REDO DONE.
set -u
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH
R=${0:a:h}
export TMPDIR=$R
cd ~/code/edge-agent-lab/ios/bench
until grep -q "ALL DONE" "$R/driver.log"; do sleep 30; done
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$R/driver.log" }
rename_new() {
  python3 - "$R" "$1" "$2" <<'PY'
import json, os, sys, glob
R, scenario, lane = sys.argv[1:4]
for p in sorted(glob.glob(os.path.join(R, "toolbench-*.jsonl"))):
    run = {}
    with open(p) as f:
        for line in f:
            try: r = json.loads(line)
            except Exception: continue
            if r.get("type") == "run": run = r; break
    if not run:
        os.rename(p, os.path.join(R, "error-" + os.path.basename(p))); print("  -> error-", os.path.basename(p)); continue
    model = (run.get("model") or "unknown").lower().replace("_", "-")
    cond = f"-{run.get('guided','')}-schema{str(run.get('schemaInPrompt','')).lower()}" if lane == "guided" else ""
    new = os.path.join(R, f"device-{scenario}-{lane}{cond}-{model}.jsonl")
    if os.path.exists(new):
        base, ext = os.path.splitext(new); i = 2
        while os.path.exists(f"{base}-{i}{ext}"): i += 1
        new = f"{base}-{i}{ext}"
    os.rename(p, new); print("  ->", os.path.basename(new))
PY
}
rm -f "$R"/device-*-unknown*.jsonl
for s in coffee-run photo-editing chains; do
  [[ -f "$R/device-$s-tools-apple-fm.jsonl" ]] && continue
  log "== REDO tools $s (apple)"
  SCENARIO=$s ./run-device.sh apple 2>&1 | tee -a "$R/driver.log"
  rename_new $s tools | tee -a "$R/driver.log"
done
for sp in yes no; do for s in coffee-run photo-editing chains; do
  flag=$([[ $sp == yes ]] && echo true || echo false)
  [[ -f "$R/device-$s-guided-constrained-schema$flag-apple-fm.jsonl" ]] && continue
  log "== REDO guided apple $s schema-in-prompt=$sp"
  LANE=guided SCHEMA_IN_PROMPT=$sp SCENARIO=$s ./run-device.sh apple 2>&1 | tee -a "$R/driver.log"
  rename_new $s guided | tee -a "$R/driver.log"
done; done
log "APPLE REDO DONE"
