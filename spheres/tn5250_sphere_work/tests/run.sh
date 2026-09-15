#!/usr/bin/env bash
set -euo pipefail
GOPHER_ROOT="${GOPHER_ROOT:-${1:-}}"
if [[ -z "$GOPHER_ROOT" ]]; then
  echo "FAIL: set GOPHER_ROOT or pass the LLM Gopher root as argv[1]" >&2
  exit 2
fi
G="$GOPHER_ROOT/engine/gopher.py"
CORE="$GOPHER_ROOT/packs/core"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PACK="$HERE/packs/terminal-machine"
PYTHON="${PYTHON:-python3}"

v="$($PYTHON "$G" --version)"
[[ "$v" == *"LLM Gopher v0.19-dev1"* ]] || { echo "FAIL gopher version: $v" >&2; exit 1; }

$PYTHON "$G" sphere edit validate terminal-machine --path "$HERE" > /tmp/terminal_machine_validate.json
grep -q '"class": "VALID"' /tmp/terminal_machine_validate.json
grep -q '"problem_count": 0' /tmp/terminal_machine_validate.json

ctx="$($PYTHON "$G" --pack "$CORE" --pack "$PACK" context terminal-machine --full)"
grep -q '"class": "OPENED"' <<<"$ctx"
grep -q '"id": "ref.terminal-machine.release-v021"' <<<"$ctx"
grep -q '"id": "terminal-machine.lessons"' <<<"$ctx"

one="$($PYTHON "$G" --pack "$CORE" --pack "$PACK" lookup 'topic=one-writer-many-readers' --sphere terminal-machine --corpus terminal-machine.lessons)"
grep -q '"class": "FOUND"' <<<"$one"
grep -q '"match_kind": "EXACT_FIELD"' <<<"$one"
grep -q 'One live terminal mutation owner' <<<"$one"

secret="$($PYTHON "$G" --pack "$CORE" --pack "$PACK" open ref.terminal-machine.secret-boundary)"
grep -q '"class": "OPENED"' <<<"$secret"
grep -q 'NONDISPLAY' <<<"$secret"

emu="$($PYTHON "$G" --pack "$CORE" --pack "$PACK" lookup 'topic=emulator-only-rewind' --sphere terminal-machine --corpus terminal-machine.lessons)"
grep -q '"class": "FOUND"' <<<"$emu"
grep -q 'LIVE_HOST' <<<"$emu"

echo "PASS terminal-machine TN5250 Gopher sphere v0.1"
