#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
: "${JOURNAL_POINTED_STATE_HOME:?set JOURNAL_POINTED_STATE_HOME to oorexx_journal_pointed_state_v0.1 package root}"
export REXX_PATH="$ROOT/src:$JOURNAL_POINTED_STATE_HOME/src${REXX_PATH:+:$REXX_PATH}"
pass=0
for t in "$ROOT"/tests/*.rex; do
  echo "==> $(basename "$t")"
  "$REXX" "$t"
  pass=$((pass+1))
done
echo "PASS $pass/$pass FederationBank Merchant Bank tests"
