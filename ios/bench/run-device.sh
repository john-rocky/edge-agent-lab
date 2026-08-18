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
set -u
DEVICE=A6F3E849-1947-5202-9AD1-9C881CA58EEF
BUNDLE=com.lfmtools.app
HERE=${0:a:h}
DEST=${TMPDIR:-/tmp}
MODELS=("$@")
(( ${#MODELS} )) || MODELS=(apple 1.2B-Instruct 2.6B)

list_files() {
  xcrun devicectl device info files --device "$DEVICE" \
    --domain-type appDataContainer --domain-identifier "$BUNDLE" \
    --subdirectory Documents 2>/dev/null
}

echo "pushing cases..."
xcrun devicectl device copy to --device "$DEVICE" \
  --domain-type appDataContainer --domain-identifier "$BUNDLE" \
  --source "$HERE/cases/core-20.json" \
  --destination "Documents/toolbench-cases.json" || exit 1

for model in "${MODELS[@]}"; do
  baseline=$(list_files | grep -oE "toolbench-[0-9]+\.done" | sort | tail -1)
  echo "== $model (baseline: ${baseline:-none})"
  # The launch step tolerates the CoreDevice hang seen on 2026-08-18: if it
  # does not return in 20s, tap the app icon on the phone — but then the
  # launch args are lost, so prefer replugging the cable and rerunning.
  timeout 20 xcrun devicectl device process launch --terminate-existing \
    --device "$DEVICE" "$BUNDLE" --toolbench --model "$model" >/dev/null 2>&1 \
    || echo "  launch did not return — if the app is not on screen, replug and rerun"

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
  tail -1 "$DEST/$jsonl"
done
