#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TM_ROOT=${TERMINAL_MACHINE_ROOT:-}
OUT=${MVS_INTENTION_EVIDENCE_DIR:-$PWD/mvs-intention-terminal-machine-dual}
mkdir -p "$OUT/ED209Z/discovery" "$OUT/ED209ZZ/discovery"

[[ -n "$TM_ROOT" ]] || { echo "BLOCKED TERMINAL_MACHINE_ROOT is required"; exit 2; }
[[ -n ${TSO_PASSWORD:-} ]] || { echo "BLOCKED TSO_PASSWORD is required for authenticated qualification"; exit 2; }

run_one(){
  local target=$1 host=$2 lu=$3 dir="$OUT/$target"
  echo "QUALIFY $target host=$host lu=$lu"
  "$ROOT/tools/run_terminal_machine_tso_discovery.sh" "$target" "$host" 3270 "$lu" \
    > "$dir/discovery/terminal_machine.tsv"
  grep -q $'^FACT\tSESSION\tTARGET\t'"$target"$'\t' "$dir/discovery/terminal_machine.tsv"
  grep -q $'^FACT\tSESSION\tHOST\t'"$host"$'\t' "$dir/discovery/terminal_machine.tsv"
  grep -q $'^FACT\tSESSION\tAUTHENTICATED\tTRUE\t' "$dir/discovery/terminal_machine.tsv"
  grep -q $'^FACT\tSESSION\tSTATE\tTSO_READY\t' "$dir/discovery/terminal_machine.tsv"
  grep -q $'^PROBE\tTERMINAL_MACHINE_LOGOFF_VERIFIED\t' "$dir/discovery/terminal_machine.tsv"
  echo "PASS $target Terminal Machine authenticated READY and clean LOGOFF"
}

run_one ED209Z 52.146.17.8 00C0
run_one ED209ZZ 20.114.63.150 00C0

! grep -q $'^FACT\tSESSION\tTARGET\tED209ZZ\t' "$OUT/ED209Z/discovery/terminal_machine.tsv"
! grep -q $'^FACT\tSESSION\tTARGET\tED209Z\t' "$OUT/ED209ZZ/discovery/terminal_machine.tsv"
echo "PASS dual target separation"
