#!/bin/zsh
# Device run driver, 2026-09-04: tools lane (3 packs × 1.2B + apple) then the
# guided lane (1.2B × 4 conditions, apple × 2), every pulled JSONL renamed by
# its run line. Log: driver.log next to this file.
set -u
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH
R=${0:a:h}
export TMPDIR=$R
cd ~/code/edge-agent-lab/ios/bench
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
for s in coffee-run photo-editing chains; do
  log "== tools $s (1.2B-Instruct, apple)"
  SCENARIO=$s ./run-device.sh 1.2B-Instruct apple 2>&1 | tee -a "$R/driver.log"
  rename_new $s tools | tee -a "$R/driver.log"
done
for g in prompt constrained; do for sp in yes no; do for s in coffee-run photo-editing chains; do
  log "== guided 1.2B $s guided=$g schema-in-prompt=$sp"
  LANE=guided GUIDED=$g SCHEMA_IN_PROMPT=$sp SCENARIO=$s ./run-device.sh 1.2B-Instruct 2>&1 | tee -a "$R/driver.log"
  rename_new $s guided | tee -a "$R/driver.log"
done; done; done
for sp in yes no; do for s in coffee-run photo-editing chains; do
  log "== guided apple $s schema-in-prompt=$sp"
  LANE=guided SCHEMA_IN_PROMPT=$sp SCENARIO=$s ./run-device.sh apple 2>&1 | tee -a "$R/driver.log"
  rename_new $s guided | tee -a "$R/driver.log"
done; done
log "ALL DONE"
