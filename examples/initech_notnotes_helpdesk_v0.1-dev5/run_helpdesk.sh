#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-$(command -v rexx)}"
export REXX_PATH="$ROOT/src:$ROOT/deps/notnotes_app/src:$ROOT/deps/notnotes_app/vendor/notnotes:$ROOT/deps/notnotes_app/vendor/nosql:$ROOT/deps/notnotes_app/vendor/pdf/src:$ROOT/deps/notnotes_app/vendor/cliui/rexx:$ROOT/deps/notnotes_intentions:$ROOT/deps/intention_service/src:$ROOT/deps/intention_service/src/nlp:${REXX_PATH:-}"
cd "$ROOT/deps/notnotes_app"
exec "$REXX" "$ROOT/run_helpdesk.rex"
