#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python3 "$ROOT/tests/test_static.py"
if [ -z "${REXX:-}" ]; then REXX=$(command -v rexx || true); fi
if [ -z "$REXX" ] || [ ! -x "$REXX" ]; then
  echo 'NOT_RUN native ooRexx: no executable REXX; autobuilder qualification fails closed' >&2
  exit 3
fi
REXX="$REXX" sh "$ROOT/tests/run.sh"
