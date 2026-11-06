#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
exec "${REXX_BIN:-rexx}" "$ROOT/bin/train450_v2.rex" "$@"
