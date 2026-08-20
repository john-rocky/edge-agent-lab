#!/bin/zsh
# Run the tool-calling bench on the Mac — same runner, same cases, no phone.
#
# The lfm-tools-ios app builds for Mac Catalyst (target LFMToolsMac; no LiteRT
# engine in that build, so Apple's model is the only backend). Apple FM on the
# Mac is the same model family as on the phone but a different machine: treat
# these runs as routing smoke tests, not as rows for the model table —
# docs/model-routing.md stays device-measured.
#
#   ./run-mac.sh video-editing            # one scenario
#   ./run-mac.sh video-editing store audio docs   # several, in sequence
#
# The Mac build keeps its files in ~/Library/Application Support/LFMTools
# (deliberately not ~/Documents, which is TCC-protected: the consent dialog
# would hang a run driven from a shell). Results land next to the device
# results, prefixed mac-.
set -u
# nomatch off, not null_glob: with null_glob an unmatched "ls pattern"
# becomes a bare ls of the cwd — the wait loop exited instantly and the
# whole run pulled nothing.
unsetopt nomatch
HERE=${0:a:h}
APP=~/code/LiteRT-Models/lfm-tools-ios/build/Build/Products/Debug-maccatalyst/LFMToolsMac.app/Contents/MacOS/LFMToolsMac
FILES=~/Library/"Application Support"/LFMTools
# BENCH_OUT overrides the destination — a second run on the same day must
# not overwrite the committed baseline JSONL for that date.
OUT="${BENCH_OUT:-$HERE/results/$(date +%Y-%m-%d)-mac}"
mkdir -p "$OUT" "$FILES"

[[ -x "$APP" ]] || { echo "no Mac build at $APP — build the LFMToolsMac scheme first"; exit 1; }

for SCENARIO in "$@"; do
  # The cross-domain runs: the merged 41-tool business list against one
  # pack's cases, with that pack's own instructions pinned — tool count is
  # the only variable.
  CASES_DIR=$SCENARIO
  INSTR=""
  LADDER=""
  case "$SCENARIO" in
    coffee-run) TOOLSET=demo ;;
    photo-editing) TOOLSET=photo ;;
    focus) TOOLSET=focus ;;
    field-report) TOOLSET=report ;;
    video-editing) TOOLSET=video ;;
    store) TOOLSET=store ;;
    audio) TOOLSET=audio ;;
    docs) TOOLSET=docs ;;
    shopping) TOOLSET=shopping ;;
    money) TOOLSET=money ;;
    inbox) TOOLSET=inbox ;;
    crm) TOOLSET=crm ;;
    pm) TOOLSET=pm ;;
    business-crm) TOOLSET=business; CASES_DIR=crm; INSTR=crm ;;
    business-pm) TOOLSET=business; CASES_DIR=pm; INSTR=pm ;;
    business-store) TOOLSET=business; CASES_DIR=store; INSTR=store ;;
    # The tool-count ladder (evaluation program #1): `ladder-<group>` runs one
    # subset from ladder.json — the business list cut down with --only, the
    # pack's instructions pinned, and only the cases whose correct tools the
    # subset holds (ladder.py's first-match partition).
    ladder-*)
      LADDER=${SCENARIO#ladder-}
      TOOLSET=business
      INSTR=$(python3 "$HERE/ladder.py" pack "$LADDER") || exit 1
      CASES_DIR=$INSTR
      ;;
    *) echo "unknown scenario $SCENARIO"; exit 1 ;;
  esac
  CASES="$HERE/../scenarios/$CASES_DIR/cases.json"
  [[ -f "$CASES" ]] || { echo "no cases at $CASES"; exit 1; }
  if [[ -n "$LADDER" ]]; then
    python3 "$HERE/ladder.py" cases "$LADDER" > "$FILES/toolbench-cases.json" || exit 1
  else
    cp "$CASES" "$FILES/toolbench-cases.json"
  fi
  rm -f "$FILES"/toolbench-*.jsonl "$FILES"/toolbench-*.done
  EXTRA=()
  [[ -n "$INSTR" ]] && EXTRA=(--instructions "$INSTR")
  [[ -n "$LADDER" ]] && EXTRA+=(--only "$(python3 "$HERE/ladder.py" tools "$LADDER")")
  echo "== $SCENARIO (toolset $TOOLSET${INSTR:+, instructions $INSTR}) on Apple FM, Mac"
  "$APP" --toolbench --toolset "$TOOLSET" $EXTRA --model apple >/dev/null 2>&1 &
  PID=$!
  # Up to 30 min per pack: a records pack with big state blocks and chains
  # runs 10-20 s a case, and the docs pack blew an 8-minute cap.
  for i in {1..300}; do
    if ls "$FILES"/toolbench-*.done >/dev/null 2>&1; then break; fi
    sleep 6
  done
  kill $PID 2>/dev/null
  JSONL=$(ls -t "$FILES"/toolbench-<->.jsonl 2>/dev/null | head -1)
  if [[ -z "$JSONL" ]]; then echo "  no result written"; continue; fi
  DEST="$OUT/mac-$SCENARIO-apple-fm.jsonl"
  mv "$JSONL" "$DEST"
  rm -f "$FILES"/toolbench-*.done
  python3 - "$DEST" <<'EOF'
import json,sys
passed=failed=0
for line in open(sys.argv[1]):
    r=json.loads(line)
    if r.get("type") in ("run","summary","start","skip","abort","error"): continue
    if r.get("pass"): passed+=1
    else:
        failed+=1
        print(f"  FAIL {r['case']}: expected {r.get('expected')} called {r.get('called')}"
              + (f" (asked={r.get('asked')})" if 'expectAsk' in r else ""))
print(f"  {passed}/{passed+failed}")
EOF
done