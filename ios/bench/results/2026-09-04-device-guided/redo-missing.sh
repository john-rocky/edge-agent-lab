#!/bin/zsh
# After the main driver: re-run every run whose result is missing or partial
# (a run without a summary line, or a summary with fewer cases than the pack
# has). Partials are kept as partial-*.jsonl. Appends to driver.log; ends with
# REDO DONE.
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
        os.rename(p, os.path.join(R, "error-" + os.path.basename(p))); print("  -> error-" + os.path.basename(p)); continue
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
# complete <file> <expected cases>: 0 when the file has a full summary; else
# moves it aside as partial-*.jsonl and returns 1.
complete() {
  python3 - "$1" "$2" <<'PY'
import json, os, sys
p, want = sys.argv[1], int(sys.argv[2])
if not os.path.exists(p): sys.exit(1)
total = -1
for line in open(p):
    try: r = json.loads(line)
    except Exception: continue
    if r.get("type") == "summary": total = r.get("total", -1)
if total >= want: sys.exit(0)
os.rename(p, os.path.join(os.path.dirname(p), "partial-" + os.path.basename(p)))
sys.exit(1)
PY
}
cases() { case $1 in coffee-run) echo 20 ;; photo-editing) echo 30 ;; chains) echo 10 ;; esac }
rm -f "$R"/device-*-unknown*.jsonl
LFM=lfm2.5-1.2b-instruct-int4
for pass in 1 2; do
  for s in coffee-run photo-editing chains; do
    n=$(cases $s)
    if ! complete "$R/device-$s-tools-$LFM.jsonl" $n; then
      log "== REDO tools $s (1.2B-Instruct) pass $pass"
      SCENARIO=$s ./run-device.sh 1.2B-Instruct 2>&1 | tee -a "$R/driver.log"; rename_new $s tools | tee -a "$R/driver.log"
    fi
    if ! complete "$R/device-$s-tools-apple-fm.jsonl" $n; then
      log "== REDO tools $s (apple) pass $pass"
      SCENARIO=$s ./run-device.sh apple 2>&1 | tee -a "$R/driver.log"; rename_new $s tools | tee -a "$R/driver.log"
    fi
  done
  for g in prompt constrained; do for sp in yes no; do for s in coffee-run photo-editing chains; do
    flag=$([[ $sp == yes ]] && echo true || echo false)
    if ! complete "$R/device-$s-guided-$g-schema$flag-$LFM.jsonl" 10; then
      log "== REDO guided 1.2B $s guided=$g schema-in-prompt=$sp pass $pass"
      LANE=guided GUIDED=$g SCHEMA_IN_PROMPT=$sp SCENARIO=$s ./run-device.sh 1.2B-Instruct 2>&1 | tee -a "$R/driver.log"; rename_new $s guided | tee -a "$R/driver.log"
    fi
  done; done; done
  for sp in yes no; do for s in coffee-run photo-editing chains; do
    flag=$([[ $sp == yes ]] && echo true || echo false)
    if ! complete "$R/device-$s-guided-constrained-schema$flag-apple-fm.jsonl" 10; then
      log "== REDO guided apple $s schema-in-prompt=$sp pass $pass"
      LANE=guided SCHEMA_IN_PROMPT=$sp SCENARIO=$s ./run-device.sh apple 2>&1 | tee -a "$R/driver.log"; rename_new $s guided | tee -a "$R/driver.log"
    fi
  done; done
done
log "REDO DONE"
