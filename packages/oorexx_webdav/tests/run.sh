#!/usr/bin/env bash
set -euo pipefail
: "${REXX:?set REXX to ooRexx interpreter}"
D="$(cd "$(dirname "$0")" && pwd)"
"$REXX" "$D/test_core.rex"
"$REXX" "$D/test_sequential_media.rex"
"$REXX" "$D/test_https_adapter.rex"
"$REXX" "$D/test_dev3_core_features.rex"
"$REXX" "$D/test_dev3_https_semantics.rex"
"$REXX" "$D/test_dev3_lock_journal.rex"
"$REXX" "$D/test_dev3_queue_objects.rex"
"$REXX" "$D/test_dev4_if_shared_locks.rex"
"$REXX" "$D/test_dev4_sync_report.rex"
"$REXX" "$D/test_dev4_sync_journal.rex"
"$REXX" "$D/test_dev4_streaming.rex"
echo 'WEBDAV DEV4 LOCAL SUITE: 11/11 PASS'
