#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COLLECTED=${1:-$ROOT/collected_results}
RANK=${2:-rank_01.wav}
OOREXX_PREFIX=${OOREXX_PREFIX:-/usr/local}
REXX_BIN=${REXX_BIN:-$OOREXX_PREFIX/bin/rexx}
[[ -x "$REXX_BIN" ]] || { echo "FAIL: ooRexx rexx not found at $REXX_BIN" >&2; exit 2; }
"$REXX_BIN" -v 2>&1 | grep -q 'Open Object Rexx Version 5.3.0 r13196' || { echo 'FAIL: exact ooRexx 5.3.0 r13196 required' >&2; exit 2; }
"$ROOT/ensure_native_runtime.sh"
export REXX_PATH="$ROOT/lib:$ROOT/foreign:$OOREXX_PREFIX/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/foreign:$OOREXX_PREFIX/lib:$OOREXX_PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
corpus="$ROOT/reference/QUALITY_CORPUS.tsv"
bridge="$ROOT/foreign/audio-search-native.bridge.json"
count=0
for node in ed209a ed209b ed209c ed209d ed209e ed209i; do
  src="$COLLECTED/$node/$RANK"
  [[ -f "$src" ]] || continue
  parent="$node:$RANK"
  catalog="$COLLECTED/$node/review_candidates.tsv"
  if [[ -f "$catalog" ]]; then
    found=$(awk -F '\t' -v r="${RANK#rank_}" 'NR>1 {gsub(/^0+/,"",r); rr=$3+0; target=r+0; if(rr==target){print $1; exit}}' "$catalog" 2>/dev/null || true)
    [[ -n "$found" ]] && parent="$found"
  fi
  out="$COLLECTED/$node/${RANK%.wav}_band_refine"
  rm -rf "$out"; mkdir -p "$out"
  "$REXX_BIN" "$ROOT/bin/AudioBandRefinement.rex" "$src" "$corpus" "$out" "$bridge" "$parent" 12
  count=$((count+1))
done
[[ $count -gt 0 ]] || { echo "FAIL: no $RANK candidates found below $COLLECTED" >&2; exit 3; }
echo "PASS band refinement completed nodes=$count rank=$RANK"
