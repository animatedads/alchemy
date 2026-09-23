#!/bin/sh
set -eu

if [ -z "${REXX:-}" ]; then
  REXX="$(command -v rexx || true)"
fi
if [ -z "$REXX" ]; then
  echo "ERROR: set REXX or place ooRexx rexx on PATH" >&2
  exit 2
fi

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

for test in "$ROOT"/tests/*.rex; do
  echo "== $(basename "$test") =="
  "$REXX" "$test"
done
