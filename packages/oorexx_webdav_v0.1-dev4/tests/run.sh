#!/usr/bin/env bash
set -euo pipefail
: "${REXX:?set REXX to ooRexx interpreter}"
"$REXX" "$(dirname "$0")/test_core.rex"
"$REXX" "$(dirname "$0")/test_https_adapter.rex"
"$REXX" "$(dirname "$0")/test_queue.rex"
"$REXX" "$(dirname "$0")/test_sequential_media.rex"
"$REXX" "$(dirname "$0")/test_storage_content.rex"
"$REXX" "$(dirname "$0")/test_hercules_paper.rex"
"$REXX" "$(dirname "$0")/test_tape_codecs.rex"
echo 'WEBDAV SUITE: 7/7 PASS'
