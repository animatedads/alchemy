#!/bin/sh
set -eu
: "${REXX_BIN:=rexx}"
export REXX_PATH="$(CDPATH= cd -- "$(dirname "$0")/../src" && pwd)${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$(dirname "$0")/test_ingress.rex"
