#!/usr/bin/env bash
set -euo pipefail
: "${REXX:?set REXX to ooRexx interpreter}"
"$REXX" "$(dirname "$0")/test_core.rex"
"$REXX" "$(dirname "$0")/test_https_adapter.rex"
"$REXX" "$(dirname "$0")/test_queue.rex"
echo 'WEBDAV SUITE: 3/3 PASS'
