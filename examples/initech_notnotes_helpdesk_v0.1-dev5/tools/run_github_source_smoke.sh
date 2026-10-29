#!/usr/bin/env bash
set -euo pipefail

HELP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$HELP_ROOT/../.." && pwd)"
MINI="$REPO_ROOT/packages/notnotes_mini_approval_app_v0.1-dev16"
NOTNOTES="$REPO_ROOT/packages/alchemy_notnotes_v0.1-dev15"
INTENT="$REPO_ROOT/packages/oorexx_intention_service"
INST="$REPO_ROOT/packages/oorexx_instrumentation_mesh"
INST_INT="$REPO_ROOT/packages/oorexx_instrumentation_intentions"

for p in "$MINI/src/MiniNotesApp.cls"          "$NOTNOTES/src/AlchemyNotNotesIntentions.cls"          "$INTENT/src/IntentionService.cls"          "$INST/src/InstrumentationMesh.cls"          "$INST_INT/src/InstrumentationIntentions.cls"; do
  [[ -f "$p" ]] || { echo "FAIL missing committed dependency: $p" >&2; exit 2; }
done

REXX="${REXX:-$(command -v rexx || true)}"
REXXC="${REXXC:-$(command -v rexxc || true)}"
[[ -x "$REXX" ]] || { echo "FAIL rexx not found" >&2; exit 2; }
[[ -x "$REXXC" ]] || { echo "FAIL rexxc not found" >&2; exit 2; }

export REXX_PATH="$HELP_ROOT/src:$MINI/src:$MINI/vendor/notnotes:$MINI/vendor/nosql:$MINI/vendor/pdf/src:$MINI/vendor/cliui/rexx:$NOTNOTES/src:$INTENT/src:$INST/src:$INST_INT/src:${REXX_PATH:-}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "== interpreter =="
"$REXX" -v | head -3

echo "== compile consumer against committed source roots =="
"$REXXC" "$HELP_ROOT/src/InitechHelpDesk.cls" >/dev/null

echo "== clean-checkout source smoke =="
(
  cd "$MINI"
  TEST_DATA_ROOT="$tmp/mininotes" "$REXX" "$HELP_ROOT/tests/test_github_source_smoke.rex"
)

echo "PASS Initech Help Desk committed-source smoke"
