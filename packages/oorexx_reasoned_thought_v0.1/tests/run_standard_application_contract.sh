#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$BASE/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
REXX_PATH="$ROOT/src" "$REXX_BIN" "$ROOT/tests/test_standard_application_contract_gpt6.rex"
