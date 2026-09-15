#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
REXX=${REXX:-rexx}
exec "$REXX" tests/test_core.rex
