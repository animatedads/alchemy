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

$PYTHON "$G" sphere edit validate terminal-machine --path "$HERE" > /tmp/terminal_machine_validate.json
grep -q '"class": "VALID"' /tmp/terminal_machine_validate.json
grep -q '"problem_count": 0' /tmp/terminal_machine_validate.json

ctx="$($PYTHON "$G" --pack "$CORE" --pack "$PACK" context terminal-machine --full)"
grep -q '"class": "OPENED"' <<<"$ctx"
grep -q '"id": "ref.terminal-machine.3270-current"' <<<"$ctx"
grep -q '"id": "terminal-machine.lessons"' <<<"$ctx"

p0="$($PYTHON "$G" --pack "$CORE" --pack "$PACK" lookup 'topic=3270-p0' --sphere terminal-machine --corpus terminal-machine.lessons)"
grep -q '"class": "FOUND"' <<<"$p0"
grep -q 'IBM 3270' <<<"$p0"

one="$($PYTHON "$G" --pack "$CORE" --pack "$PACK" lookup 'topic=one-writer-many-readers' --sphere terminal-machine --corpus terminal-machine.lessons)"
grep -q '"class": "FOUND"' <<<"$one"
grep -q 'One live terminal mutation owner' <<<"$one"

secret="$($PYTHON "$G" --pack "$CORE" --pack "$PACK" open ref.terminal-machine.secret-boundary)"
grep -q '"class": "OPENED"' <<<"$secret"
grep -q 'NONDISPLAY' <<<"$secret"

echo "PASS terminal-machine Gopher sphere v0.2"
