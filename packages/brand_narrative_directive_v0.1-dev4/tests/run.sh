#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
REXX_BIN=${REXX_BIN:-rexx}
for t in \
  compile_smoke.rex \
  test_positive_projection.rex \
  test_unmanaged_positive_blocked.rex \
  test_non_positive_mappings.rex \
  test_kind_mismatch.rex \
  test_external_evidence_authority.rex \
  test_projection_snapshot.rex \
  test_fresh_handoff_verification.rex \
  test_no_change_handoff.rex \
  test_pause_handoff_verification.rex \
  test_communications_review_adapter.rex \
  test_communications_hold_blocks.rex \
  test_librarian_position_adapter.rex \
  test_librarian_change_adapter.rex \
  test_librarian_change_non_authority.rex \
  test_librarian_origin_adapter.rex \
  test_librarian_origin_non_authority.rex; do
  echo "== $t =="
  "$REXX_BIN" "$t"
done
