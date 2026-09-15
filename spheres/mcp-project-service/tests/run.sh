#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21-dev1 or later}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
"$GOPHER" sphere edit validate mcp-project-service --path "$ROOT"
"$GOPHER" sphere edit lint mcp-project-service --path "$ROOT"
echo "PASS mcp-project-service sphere v0.2-dev8"
