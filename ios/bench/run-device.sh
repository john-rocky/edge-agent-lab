#!/bin/zsh
# Run the tool-calling bench on the phone and pull the JSONL back.
#
# One app launch per model: the engines do not reliably give memory back
# mid-process, so per-model attribution needs per-launch isolation. Requires
# the phone plugged in and unlocked, the LFMTools app installed (from
# LiteRT-Models/lfm-tools-ios), and the LiteRT bundles already in its
# Documents.
#
#   ./run-device.sh                   # apple, 1.2B-Instruct, 2.6B
#   ./run-device.sh 1.2B-Instruct     # one model (any --model substring)
#   SCENARIO=photo-editing ./run-device.sh   # another scenario pack
set -u
DEVICE=A6F3E849-1947-5202-9AD1-9C881CA58EEF
BUNDLE=com.lfmtools.app
HERE=${0:a:h}
DEST=${TMPDIR:-/tmp}
MODELS=("$@")
(( ${#MODELS} )) || MODELS=(apple 1.2B-Instruct 2.6B)

# A scenario pack is a cases file plus the in-app tool set it was written
# against; they travel together or the run measures nothing.
SCENARIO=${SCENARIO:-coffee-run}
CASES="$HERE/../scenarios/$SCENARIO/cases.json"
case "$SCENARIO" in
  coffee-run) TOOLSET=demo ;;
  photo-editing) TOOLSET=photo ;;
  focus) TOOLSET=focus ;;
  field-report) TOOLSET=report ;;
  *) echo "unknown scenario $SCENARIO"; exit 1 ;;
esac
[[ -f "$CASES" ]] || { echo "no cases at $CASES"; exit 1; }

list_files() {
  xcrun devicectl device info files --device "$DEVICE" \
    --domain-type appDataContainer --domain-identifier "$BUNDLE" \
    --subdirectory Documents 2>/dev/null
}

echo "pushing $SCENARIO cases (toolset $TOOLSET)..."
xcrun devicectl device copy to --device "$DEVICE" \
  --domain-type appDataContainer --domain-identifier "$BUNDLE" \
  --source "$CASES" \
  --destination "Documents/toolbench-cases.json" || exit 1

for model in "${MODELS[@]}"; do
  baseline=$(list_files | grep -oE "toolbench-[0-9]+\.done" | sort | tail -1)
  echo "== $model (baseline: ${baseline:-none})"
  # The CoreDevice hang seen on 2026-08-18 is worse than an inconvenience: a
  # hung launch can still start the app WITHOUT its arguments, and with no
  # --model the app silently runs the newest bundle. Retry once; if both
  # hang, skip this model rather than launch the wrong one.
  launched=0
  for attempt in 1 2; do
    if timeout 20 xcrun devicectl device process launch --terminate-existing \
      --device "$DEVICE" "$BUNDLE" --toolbench --toolset "$TOOLSET" \
      --model "$model" >/dev/null 2>&1; then
      launched=1
      break
    fi
    echo "  launch attempt $attempt hung"
  done
  if (( ! launched )); then
    echo "  skipping $model — args would be lost on a hung launch"
    continue
  fi

  # A 20-case run is minutes on the 1.2B and tens of minutes on the 2.6B.
  done_name=""
  for i in {1..90}; do
    sleep 20
    newest=$(list_files | grep -oE "toolbench-[0-9]+\.done" | sort | tail -1)
    if [[ -n "$newest" && "$newest" != "$baseline" ]]; then
      done_name=$newest
      break
    fi
  done
  if [[ -z "$done_name" ]]; then
    echo "  no result after 30 min — did the app start with the args?"
    continue
  fi

  jsonl=${done_name%.done}.jsonl
  xcrun devicectl device copy from --device "$DEVICE" \
    --domain-type appDataContainer --domain-identifier "$BUNDLE" \
    --source "Documents/$jsonl" --destination "$DEST/$jsonl" >/dev/null 2>&1
  echo "  pulled: $DEST/$jsonl"
  # The run's own idea of its model, against what was asked for. A hung
  # launch that dropped the args shows up here as the newest bundle.
  ran=$(head -1 "$DEST/$jsonl" | grep -o '"model":"[^"]*"')
  case "$model" in
    apple) [[ "$ran" == *apple-fm* ]] || echo "  WARNED: asked apple, ran $ran" ;;
    *) [[ "${ran:l}" == *"${model:l}"* ]] || echo "  WARNED: asked $model, ran $ran" ;;
  esac
  tail -1 "$DEST/$jsonl"
done
