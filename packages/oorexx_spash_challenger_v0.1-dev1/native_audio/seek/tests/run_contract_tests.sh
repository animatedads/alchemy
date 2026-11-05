#!/bin/sh
# API-only qualification: never loads or simulates actual Ogg audio.
set -eu
cd "$(dirname "$0")/.."
export REXX_PATH="$PWD/tests/stubs:$PWD${REXX_PATH:+:$REXX_PATH}"
rexx tests/test_contract.rex
for c in ZERO_DURATION TOO_LONG BAD_CHANNEL BAD_RATE BAD_BUDGET SOURCE_COLLISION BAD_CATALOGUE; do
  log=$(mktemp)
  if rexx tests/test_reject.rex "$c" > "$log" 2>&1; then
    cat "$log" >&2
    rm -f "$log"
    echo "FAIL admitted $c" >&2
    exit 1
  fi
  if ! grep -q 'Error 88' "$log"; then
    cat "$log" >&2
    rm -f "$log"
    echo "FAIL wrong rejection $c" >&2
    exit 1
  fi
  rm -f "$log"
  echo "PASS rejected $c"
done
printf 'PASS ooRexx-only wrapper contract; actual native media provider NOT qualified\n'
