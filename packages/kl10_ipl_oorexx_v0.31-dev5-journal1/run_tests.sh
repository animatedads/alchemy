#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
: "${REXX:=rexx}"
: "${REXXC:=rexxc}"
MODE=${1:-all}

# Optional historical fixtures.  These are intentionally not embedded in the
# component ZIP.
: "${KL10_TAPE:=}"
: "${KL10_PROMPT_STATE:=}"
: "${KL10_AFTER_ENTER_STATE:=}"
: "${KL10_PRE_MAP_STATE:=}"
: "${KL10_PRE_PAGING_STATE:=}"
: "${KL10_PRE_DTE_STATE:=}"
: "${KL10_NO_READY_STATE:=}"
: "${KL10_FIRST_READ_STATE:=}"
: "${KL10_PROBE_762000_STATE:=}"
: "${KL10_SECOND_READ_STATE:=}"
: "${KL10_THIRD_READ_STATE:=}"

# Optional companion components.
: "${QUEUE_FABRIC_ROOT:=}"
: "${TERMINAL_MACHINE_ROOT:=}"

case "$MODE" in
  core|tape|states|integrations|all) ;;
  *)
    echo "usage: $0 [core|tape|states|integrations|all]" >&2
    exit 2
    ;;
esac

if ! command -v "$REXX" >/dev/null 2>&1; then
  echo "ooRexx interpreter not found: $REXX" >&2
  echo "set REXX=/path/to/rexx or add ooRexx to PATH" >&2
  exit 2
fi
if ! command -v "$REXXC" >/dev/null 2>&1; then
  echo "ooRexx compiler not found: $REXXC" >&2
  echo "set REXXC=/path/to/rexxc or add ooRexx to PATH" >&2
  exit 2
fi

parts=("$ROOT")
if [[ -n "$QUEUE_FABRIC_ROOT" && -d "$QUEUE_FABRIC_ROOT/src" ]]; then
  parts+=("$QUEUE_FABRIC_ROOT/src")
fi
if [[ -n "$TERMINAL_MACHINE_ROOT" && -d "$TERMINAL_MACHINE_ROOT/src" ]]; then
  parts+=("$TERMINAL_MACHINE_ROOT/src")
fi
joined=$(IFS=:; echo "${parts[*]}")
export REXX_PATH="$joined${REXX_PATH:+:$REXX_PATH}"

pass=0
skip=0

run() {
  local test=$1
  shift
  echo "=== $test ==="
  (
    cd "$ROOT/tests"
    "$REXX" "$test" "$@"
  )
  pass=$((pass + 1))
}

skip_test() {
  local name=$1
  local why=$2
  echo "SKIP $name ($why)"
  skip=$((skip + 1))
}

need_file() {
  [[ -n "$1" && -f "$1" ]]
}

compile_all() {
  local work
  work=$(mktemp -d)

  echo "=== compile all Rexx/class/tool sources ==="
  while IFS= read -r file; do
    "$REXXC" "$file" "$work/$(basename "$file").orx" >/dev/null
  done < <(
    find "$ROOT" -type f \( -name '*.cls' -o -name '*.rex' \) \
      ! -path "$ROOT/.test-run.*/*" | sort
  )
  rm -rf "$work"
  echo "PASS compile all"
}

run_core() {
  compile_all

  local tests=(
    test_address_space_authority.rex
    test_cpu_add_sub_family.rex
    test_cpu_andi.rex
    test_cpu_aobj.rex
    test_cpu_aoj_family.rex
    test_cpu_aos_family.rex
    test_cpu_apr_reset.rex
    test_cpu_aprid.rex
    test_cpu_blt.rex
    test_cpu_boolean_family.rex
    test_cpu_compare_family.rex
    test_cpu_dmove.rex
    test_cpu_dte_service.rex
    test_cpu_exch.rex
    test_cpu_halfword_family.rex
    test_cpu_ildb_adjsp.rex
    test_cpu_io_boundary.rex
    test_cpu_jrst_indexed.rex
    test_cpu_jsp_ac_fetch.rex
    test_cpu_jump_family.rex
    test_cpu_move_family.rex
    test_cpu_movsi.rex
    test_cpu_pag_acblocks.rex
    test_cpu_pag_coni.rex
    test_cpu_pag_cono_indexed.rex
    test_cpu_pag_datao.rex
    test_cpu_preview.rex
    test_cpu_pxct_previous_ac.rex
    test_cpu_shift_family.rex
    test_cpu_skip_family.rex
    test_cpu_skipa.rex
    test_cpu_soj_family.rex
    test_cpu_stack_ops.rex
    test_cpu_tdz.rex
    test_cpu_test_family.rex
    test_cpu_tops20_pager.rex
    test_cpu_tops20_page_fault_delivery.rex
    test_journal_instruction_branching.rex
    test_journal_tops20_page_fault_rewind.rex
    test_journal_live_opcode_patch.rex
    test_cpu_xct_io.rex
    test_cpu_zero_byte.rex
    test_execution_clear_accelerator.rex
    test_io_bus_routing.rex
    test_kl10_word.rex
    test_lroct.rex
    test_lroct_orderable.rex
    test_lroct_randomized.rex
    test_octal_bits.rex
    test_simh_framing.rex
    test_state_fail_closed.rex
    test_state_fast_freeze.rex
    test_state_freeze_load.rex
    test_state_compressed_freeze.rex
  )

  local t
  for t in "${tests[@]}"; do
    run "$t"
  done
}

run_tape() {
  if ! need_file "$KL10_TAPE"; then
    skip_test "historical tape suite" "set KL10_TAPE=/path/to/bb-h137f-bm.tap"
    return
  fi

  local tests=(
    test_kl10_ipl.rex
    test_mtboot_one_step.rex
    test_mtboot_two_steps.rex
    test_mtboot_three_steps.rex
    test_mtboot_four_steps.rex
    test_mtboot_five_steps.rex
    test_mtboot_six_steps.rex
    test_mtboot_seven_steps.rex
    test_mtboot_eight_steps.rex
    test_mtboot_nine_steps.rex
    test_mtboot_ten_steps.rex
    test_mtboot_eleven_steps.rex
    test_mtboot_fourteen_steps.rex
    test_mtboot_paging_boundary.rex
    test_mtboot_postloop_aobj.rex
    test_mtboot_twentyfour_steps.rex
    test_mtboot_twentysix_steps.rex
    test_mtboot_thirtythree_steps.rex
    test_mtboot_thirtyeight_steps.rex
    test_raw_tape_loader.rex
    test_tape_operator_panel.rex
  )
  local t
  for t in "${tests[@]}"; do
    run "$t" "$KL10_TAPE"
  done
}

run_state_if() {
  local test=$1
  local fixture=$2
  local varname=$3
  if need_file "$fixture"; then
    run "$test" "$fixture"
  else
    skip_test "$test" "set $varname"
  fi
}

run_states() {
  run_state_if test_console_keyboard.rex "$KL10_PROMPT_STATE" KL10_PROMPT_STATE
  run_state_if test_console_prompt_enter.rex "$KL10_PROMPT_STATE" KL10_PROMPT_STATE
  run_state_if test_console_state_roundtrip.rex "$KL10_PROMPT_STATE" KL10_PROMPT_STATE
  run_state_if test_cpu_dte_input.rex "$KL10_PROMPT_STATE" KL10_PROMPT_STATE
  run_state_if test_cpu_idpb_dpb_real.rex "$KL10_AFTER_ENTER_STATE" KL10_AFTER_ENTER_STATE
  run_state_if test_cpu_map.rex "$KL10_PRE_MAP_STATE" KL10_PRE_MAP_STATE
  run_state_if test_mtboot_pre_map_state.rex "$KL10_PRE_MAP_STATE" KL10_PRE_MAP_STATE
  run_state_if test_mtboot_nxm_handoff.rex "$KL10_PRE_PAGING_STATE" KL10_PRE_PAGING_STATE
  run_state_if test_mtboot_pre_dte_state.rex "$KL10_PRE_DTE_STATE" KL10_PRE_DTE_STATE
  run_state_if test_mtboot_no_ready_tape_state.rex "$KL10_NO_READY_STATE" KL10_NO_READY_STATE
  run_state_if test_first_read_integrated_state.rex "$KL10_FIRST_READ_STATE" KL10_FIRST_READ_STATE
  if need_file "$KL10_FIRST_READ_STATE" && need_file "$KL10_TAPE"; then
    run test_rh20_multiccw_read.rex "$KL10_FIRST_READ_STATE" "$KL10_TAPE"
  else
    skip_test test_rh20_multiccw_read.rex "set KL10_FIRST_READ_STATE and KL10_TAPE"
  fi
  run_state_if test_execution_probe_accelerator.rex "$KL10_FIRST_READ_STATE" KL10_FIRST_READ_STATE
  run_state_if test_execution_probe_modified_map.rex "$KL10_PROBE_762000_STATE" KL10_PROBE_762000_STATE
  run_state_if test_second_read_real_state.rex "$KL10_SECOND_READ_STATE" KL10_SECOND_READ_STATE
  run_state_if test_third_read_real_state.rex "$KL10_THIRD_READ_STATE" KL10_THIRD_READ_STATE
}

run_integrations() {
  if [[ -n "$TERMINAL_MACHINE_ROOT" && -f "$TERMINAL_MACHINE_ROOT/src/TerminalCore.cls" ]]; then
    if need_file "$KL10_PROMPT_STATE"; then
      run test_terminal_machine_v05_bridge.rex "$KL10_PROMPT_STATE"
    else
      skip_test test_terminal_machine_v05_bridge.rex \
        "Terminal Machine present; set KL10_PROMPT_STATE"
    fi
  else
    skip_test test_terminal_machine_v05_bridge.rex \
      "set TERMINAL_MACHINE_ROOT to Terminal Machine v0.5 root"
  fi

  if [[ -n "$QUEUE_FABRIC_ROOT" && -f "$QUEUE_FABRIC_ROOT/src/ObjectQueueFabric.cls" ]]; then
    if need_file "$KL10_TAPE"; then
      run test_tape_operator_queue_fabric.rex "$KL10_TAPE"
    else
      skip_test test_tape_operator_queue_fabric.rex \
        "Queue Fabric present; set KL10_TAPE"
    fi
  else
    skip_test test_tape_operator_queue_fabric.rex \
      "set QUEUE_FABRIC_ROOT to Object Queue Fabric v0.8.1 root"
  fi
}

case "$MODE" in
  core)
    run_core
    ;;
  tape)
    run_tape
    ;;
  states)
    run_states
    ;;
  integrations)
    run_integrations
    ;;
  all)
    run_core
    run_tape
    run_states
    run_integrations
    ;;
esac

echo
echo "KL10 TEST SUMMARY: PASS=$pass SKIP=$skip MODE=$MODE"
