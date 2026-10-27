#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REXX_BIN=${REXX_BIN:-rexx}
REXX_PATH="$ROOT/../src" "$REXX_BIN" "$ROOT/test_standard_application_contract_gpt6.rex"
REXX_PATH="$ROOT/../src" "$REXX_BIN" "$ROOT/test_standard_application_absolute_rule_gpt6.rex"
REXX_PATH="$ROOT/../src" "$REXX_BIN" "$ROOT/test_standard_application_label_order_gpt6.rex"
REXX_PATH="$ROOT/../src" "$REXX_BIN" "$ROOT/test_threshold_necessary.rex"
