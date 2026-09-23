#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REXX="${REXX:-rexx}"
REXXC="${REXXC:-rexxc}"
cd "$ROOT/tests"
"$REXX" test_dimensions.rex
"$REXX" test_maths_contract.rex
"$REXX" test_units.rex
"$REXX" test_dev2.rex
cd "$ROOT/examples"
"$REXX" physics_and_rexxtronics.rex
cd "$ROOT"
"$REXXC" rexx/Units.cls /tmp/oorexx_units_Units.orx
echo "PASS rexxc Units.cls"
