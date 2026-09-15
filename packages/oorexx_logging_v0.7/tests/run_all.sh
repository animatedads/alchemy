#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS="$ROOT/tests"
SRC="$ROOT/src"

: "${OOLOG_QUEUE_SRC:?set OOLOG_QUEUE_SRC to Object Queue Fabric src directory}"
: "${OOLOG_NOSQL_SRC:?set OOLOG_NOSQL_SRC to NoSQLServer src directory}"
: "${OOLOG_ALCHEMY_BASE:?set OOLOG_ALCHEMY_BASE to Alchemy package root}"
: "${OOLOG_ALCHEMY_SRC:=$OOLOG_ALCHEMY_BASE/src}"
: "${OOLOG_CRYPTO_SRC:?set OOLOG_CRYPTO_SRC to ooRexx crypto src directory}"
: "${OOLOG_POLICY_SRC:?set OOLOG_POLICY_SRC to Institutional Policy src directory}"

run_test() {
  local test="$1"
  shift
  echo "=== $test ==="
  (cd "$TESTS" && PATH="$SRC:$*:$PATH" rexx "$test")
}

run_test compile.rex ""
run_test compile_policy.rex "$OOLOG_POLICY_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_noop_cost.rex ""
run_test test_metrics_opt_in.rex ""
run_test test_deferred_payload.rex ""
run_test test_argument_semantics.rex ""
run_test test_scope_objects.rex ""
run_test test_rule_indexing.rex ""
run_test test_selective_method.rex ""
run_test test_coordinated_interposition.rex ""
run_test test_interposition_priority.rex ""
run_test test_interposition_failure.rex ""
run_test test_selective_proxy.rex ""
run_test test_points.rex ""
run_test test_controls.rex ""
run_test test_target_switch.rex ""
run_test test_scope_authority.rex "$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_scope_domain_authority.rex "$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_policy_catalog.rex "$OOLOG_POLICY_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_policy_identity.rex "$OOLOG_POLICY_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_policy_publication_authority.rex "$OOLOG_POLICY_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_policy_crypto_separation.rex "$OOLOG_POLICY_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_policy_activation_atomic.rex "$OOLOG_POLICY_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_policy_progressive_rollout.rex "$OOLOG_POLICY_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_alchemy_preexisting_telemetry.rex "$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_alchemy_v07_execution_provenance.rex "$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_alchemy_v08_logging_first.rex "$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_nosql_object_table.rex "$OOLOG_NOSQL_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_runtime_control_nosql.rex "$OOLOG_NOSQL_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_control_journal_bound.rex "$OOLOG_NOSQL_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_dormant_runtime_activation.rex "$OOLOG_NOSQL_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_queue_target.rex "$OOLOG_QUEUE_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_queue_topic_target.rex "$OOLOG_QUEUE_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_queue_domain_scope.rex "$OOLOG_QUEUE_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_queue_legacy_event_v01.rex "$OOLOG_QUEUE_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_queue_legacy_event_v02.rex "$OOLOG_QUEUE_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_queue_legacy_event_v03.rex "$OOLOG_QUEUE_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"
run_test test_queue_persistent_target.rex "$OOLOG_QUEUE_SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC"

echo "=== test_locked_method_logging.rex ==="
(
  cd "$OOLOG_ALCHEMY_BASE/tests"
  PATH="$SRC:$OOLOG_ALCHEMY_SRC:$OOLOG_CRYPTO_SRC:$PATH" rexx "$TESTS/test_locked_method_logging.rex"
)

echo "ALL LOGGING TESTS PASS"
