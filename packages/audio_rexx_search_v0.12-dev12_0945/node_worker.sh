#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
NODE=${1:?node required}
JOB="$ROOT/jobs/$NODE.conf"
[[ -f "$JOB" ]] || { echo "Unknown/forbidden node $NODE" >&2; exit 2; }
OOREXX_PREFIX=${OOREXX_PREFIX:-/usr/local}
REXX_BIN=${REXX_BIN:-$OOREXX_PREFIX/bin/rexx}
REXXC_BIN=${REXXC_BIN:-$OOREXX_PREFIX/bin/rexxc}
ver=$("$REXX_BIN" -v 2>&1 || true)
grep -q 'Open Object Rexx Version 5.3.0 r13196' <<<"$ver" || { echo 'FAIL: exact ooRexx 5.3.0 r13196 required' >&2; exit 3; }
[[ -x "$REXXC_BIN" ]] || { echo "FAIL: $REXXC_BIN missing" >&2; exit 3; }
[[ $(uname -m) == x86_64 ]] || { echo 'FAIL: this dev5 native kernel is x86_64 only' >&2; exit 3; }
(cd "$ROOT" && sha256sum -c MANIFEST.sha256 >/dev/null)
(cd "$ROOT" && sha256sum -c SAMPLES.sha256 >/dev/null)

budget_gib=$(awk -F= '$1=="workspace_budget_gib" {print $2; exit}' "$JOB")
[[ "$budget_gib" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "FAIL: workspace_budget_gib missing/invalid in $JOB" >&2; exit 3; }
budget_bytes=$(awk -v g="$budget_gib" 'BEGIN { printf "%.0f", g*1073741824 }')
reserve_bytes=1073741824
free_bytes=$(df -PB1 "$ROOT" | awk 'NR==2 {print $4}')
need_bytes=$((budget_bytes + reserve_bytes))
if (( free_bytes < need_bytes )); then
  echo "FAIL: $NODE free disk $free_bytes bytes is below workspace allowance + 1 GiB reserve ($need_bytes bytes)" >&2
  exit 6
fi
memory_total_min_mib=$(awk -F= '$1=="memory_total_min_mib" {print $2; exit}' "$JOB")
if [[ -n "$memory_total_min_mib" ]]; then
  mem_total_mib=$(awk '/^MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)
  if (( mem_total_mib < memory_total_min_mib )); then
    echo "FAIL: $NODE total memory ${mem_total_mib} MiB below required ${memory_total_min_mib} MiB" >&2
    exit 6
  fi
  echo "MEMORY PREFLIGHT node=$NODE total_mib=$mem_total_mib required_mib=$memory_total_min_mib"
fi
swap_total_min_mib=$(awk -F= '$1=="swap_total_min_mib" {print $2; exit}' "$JOB")
if [[ -n "$swap_total_min_mib" ]]; then
  swap_total_mib=$(awk '/^SwapTotal:/ {printf "%d", $2/1024}' /proc/meminfo)
  if (( swap_total_mib < swap_total_min_mib )); then
    echo "FAIL: $NODE total swap ${swap_total_mib} MiB below required ${swap_total_min_mib} MiB" >&2
    exit 6
  fi
  echo "SWAP PREFLIGHT node=$NODE total_mib=$swap_total_mib required_mib=$swap_total_min_mib"
fi
echo "DISK PREFLIGHT node=$NODE free_bytes=$free_bytes workspace_budget_gib=$budget_gib reserve_gib=1"

"$ROOT/ensure_native_runtime.sh"
export REXX_PATH="$ROOT/lib:$ROOT/foreign:$OOREXX_PREFIX/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/foreign:$OOREXX_PREFIX/lib:$OOREXX_PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
STATE="$ROOT/state/$NODE"
if [[ ${SEARCH_RESET_STATE:-0} == 1 ]]; then rm -rf "$STATE"; fi
mkdir -p "$STATE"
resume_key=$(cd "$ROOT" && sha256sum "jobs/$NODE.conf" SAMPLES.sha256 bin/AudioSearchExperiment.rex native/audio_search_native.c lib/AudioSearchNative.cls lib/OorexxML.cls lib/MLCore.cls lib/MLEvolution.cls lib/MLSearch.cls lib/MLReview.cls | sha256sum | awk '{print $1}')
export AUDIO_SEARCH_STATE_DIR="$STATE"
export AUDIO_SEARCH_RESUME_KEY="$resume_key"
export AUDIO_SEARCH_FSYNC_HELPER="$ROOT/foreign/audio_checkpoint_fsync"
OUT="$ROOT/results/$NODE"; rm -rf "$OUT"; mkdir -p "$OUT"
set +e
"$REXX_BIN" "$ROOT/bin/AudioSearchExperiment.rex" "$JOB" "$ROOT/sample/campaign0945_source_094330_094630.wav" "$ROOT/alignment_reference/campaign0945_companion_094315_094645.wav" "$ROOT/reference/QUALITY_CORPUS.tsv" "$OUT" "$ROOT/foreign/audio-search-native.bridge.json"
rc=$?
set -e
if [[ $rc == 0 ]]; then
  used_bytes=$(du -sb "$OUT" | awk '{print $1}')
  if (( used_bytes > budget_bytes )); then
    echo "FAIL: $NODE retained output $used_bytes bytes exceeds declared workspace budget $budget_bytes bytes" >&2
    exit 7
  fi
  printf 'workspace_budget_gib=%s\nretained_output_bytes=%s\n' "$budget_gib" "$used_bytes" > "$OUT/WORKSPACE_EVIDENCE.txt"
  if [[ $NODE == ed209e ]]; then
    cp -f "$STATE/exploration.state" "$OUT/CHECKPOINT_STATE.txt"
    cp -f "$STATE/exploration_records.tsv" "$OUT/CHECKPOINT_RECORDS.tsv"
  fi
  (cd "$OUT" && find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%P\0' | sort -z | xargs -0 sha256sum > SHA256SUMS)
fi
exit "$rc"
