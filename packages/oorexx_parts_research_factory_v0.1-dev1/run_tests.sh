#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
JSON_ROOT=${OOREXX_JSON_ROOT:-/home/hc3/alchemy/oorexx-source/extensions/json}
MATERIALS_ROOT=${OOREXX_MATERIALS_ROOT:-"$HERE/../oorexx_materials_v0.1-dev5"}
UNITS_ROOT=${OOREXX_UNITS_ROOT:-"$HERE/../oorexx_units_v0.1-dev4"}
export REXX_PATH="$HERE/src:$JSON_ROOT:$MATERIALS_ROOT/src:$UNITS_ROOT/rexx:$UNITS_ROOT/src${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
rexx test_research_factory.rex
