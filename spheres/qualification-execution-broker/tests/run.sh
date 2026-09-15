#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21-dev1 or later}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
"$GOPHER" sphere edit validate qualification-execution-broker --path "$ROOT"
"$GOPHER" sphere edit lint qualification-execution-broker --path "$ROOT"
echo "PASS qualification-execution-broker sphere v0.1-dev1"
