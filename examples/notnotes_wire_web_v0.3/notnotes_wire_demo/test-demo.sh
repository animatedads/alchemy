#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$HERE/env.sh"
"$OOREXX_HOME/bin/rexx" -v | head -n 1
node "$HERE/acceptance-stack.mjs"
node "$HERE/acceptance-dom.mjs"
echo 'PASS: NotNotes/Wire approval, creation, custom format, typed field, links, reports, intentions, refusal and restart.'
