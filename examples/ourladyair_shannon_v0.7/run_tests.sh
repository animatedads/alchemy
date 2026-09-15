#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${HARDWORLD_ROOT:?set HARDWORLD_ROOT to the HardWorld package root}"
: "${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT to the Legal Effect package root}"
: "${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT to the Runtime Registry package root}"
: "${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT to the Queue Fabric package root}"
: "${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT to the Structured Relation package root}"
: "${NOSQLSERVER_ROOT:?set NOSQLSERVER_ROOT to the NoSQLServer package root}"
: "${WLU_ROOT:?set WLU_ROOT to the Work Load Units package root}"
MODE="${1:-quick}"

run_rexx_test() {
  local test="$1"
  echo "== $(basename "$test") =="
  "$ROOT/run_rexx.sh" "$test" "$ROOT"
}

run_shell_test() {
  local test="$1"
  echo "== $(basename "$test") =="
  "$test" "$ROOT"
}

case "$MODE" in
  quick)
    # Pay the pure-ooRexx Legal Effect verification cost once, first.  The
    # remaining transport/topic/EDI probes are lightweight and isolated.
    echo "== consolidated Legal Effect / HardWorld acceptance =="
    echo "NOTE: Legal policy verification is cryptographic and CPU-bound; the consolidated suite verifies one generation and reuses it."
    run_rexx_test "$ROOT/tests/test_shannon_v07_combined_acceptance.rex"
    run_rexx_test "$ROOT/tests/test_shannon_queue_compatibility.rex"
    run_shell_test "$ROOT/tests/test_shannon_no_hard_release_gates.sh"
    run_rexx_test "$ROOT/tests/test_shannon_topic_bus.rex"
    run_rexx_test "$ROOT/tests/test_shannon_wlu_terminal_gate.rex"
    run_rexx_test "$ROOT/tests/test_shannon_pnrgov_parse.rex"
    run_rexx_test "$ROOT/tests/test_shannon_pnrgov_compact_parse.rex"
    run_shell_test "$ROOT/tests/test_shannon_socket_ingress.sh"
    ;;
  full)
    for test in "$ROOT"/tests/test_*.rex; do run_rexx_test "$test"; done
    for test in "$ROOT"/tests/test_*.sh; do [[ -e "$test" ]] && run_shell_test "$test"; done
    ;;
  *)
    echo "usage: $0 [quick|full]" >&2
    exit 2
    ;;
esac
