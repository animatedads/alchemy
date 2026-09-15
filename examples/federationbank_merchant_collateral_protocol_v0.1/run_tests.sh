#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
n=0
for t in "$ROOT"/tests/*.rex; do
 echo "==> $(basename "$t")"
 "$REXX" "$t"
 n=$((n+1))
done
echo "PASS $n/$n Merchant Collateral Protocol tests"
