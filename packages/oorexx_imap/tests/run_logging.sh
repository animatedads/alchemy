#!/bin/sh
set -eu
: "${OOREXX_LOGGING_SRC:?set OOREXX_LOGGING_SRC to the ooRexx Logging v0.7 src directory}"
R="${REXX:-rexx}"
BASE_REXX_PATH="${REXX_PATH:-}"
export REXX_PATH="../src:${OOREXX_LOGGING_SRC}${BASE_REXX_PATH:+:${BASE_REXX_PATH}}"
exec "$R" test_logging_adapter.rex
