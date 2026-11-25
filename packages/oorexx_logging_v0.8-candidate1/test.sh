#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${LOGGING_BASE_HOME:?set directory containing src/LoggingCore.cls}"
export REXX_PATH="$PWD/src:$LOGGING_BASE_HOME/src${REXX_PATH:+:$REXX_PATH}"
exec "${REXX:-rexx}" tests/test-subscriptions.rex
