#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
: "${REXX:=rexx}"
for t in \
  test_night_locator.rex \
  test_occlusion_fail_closed.rex \
  test_tp00000_exclusion_contract.rex \
  test_wall_clock_window.rex \
  test_window_worker_synthetic.rex \
  test_control_state_csvstream.rex \
  test_worker_synthetic.rex \
  test_migration_bundle_tamper.rex \
  test_migration_resume_equivalence.rex \
  test_direct_payload_block.rex
do
  echo "== $t =="
  "$REXX" "$ROOT/tests/$t" "$ROOT"
done

if [ "${FD_TEST_MIGRATABLE_ADAPTER:-0}" = "1" ]; then
  echo "== test_migratable_adapter_load.rex =="
  "$REXX" "$ROOT/tests/test_migratable_adapter_load.rex" "$ROOT"
fi

if [ "${FD_TEST_MIGRATABLE_STARTER:-0}" = "1" ]; then
  echo "== test_managed_placement_fd_new.rex =="
  "$REXX" "$ROOT/tests/test_managed_placement_fd_new.rex" "$ROOT"
  echo "== test_managed_placement_fd_failure_hold.rex =="
  "$REXX" "$ROOT/tests/test_managed_placement_fd_failure_hold.rex" "$ROOT"
  echo "== test_standard_starter_fd_handoff.rex =="
  "$REXX" "$ROOT/tests/test_standard_starter_fd_handoff.rex" "$ROOT"
  echo "== test_standard_starter_fd_e2e.rex =="
  "$REXX" "$ROOT/tests/test_standard_starter_fd_e2e.rex" "$ROOT"
fi
