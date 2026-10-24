#!/bin/sh
# Native ooRexx 5.3.0 r13196 qualification, keeping dependency paths explicit.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=''
if [ -n "${REXX_BIN:-}" ]; then
  REXX=${REXX_BIN}
  RUNTIMELIB=${OOREXX_LIB:-}
  RUNTIMECLASSES=${OOREXX_CLASSES:-}
else
  if [ -z "${OOREXX_DEB:-}" ]; then
    echo 'Set REXX_BIN/OOREXX_CLASSES or OOREXX_DEB (ooRexx r13196)' >&2
    exit 2
  fi
  if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo 'dpkg-deb unavailable: extract the runtime externally and set REXX_BIN' >&2
    exit 2
  fi
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT HUP INT TERM
  dpkg-deb -x "$OOREXX_DEB" "$TMP"
  REXX="$TMP/usr/local/bin/rexx"
  RUNTIMELIB="$TMP/usr/local/lib"
  RUNTIMECLASSES="$TMP/usr/local/bin"
fi
if [ -z "$TMP" ]; then
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT HUP INT TERM
fi
if [ -n "$RUNTIMELIB" ]; then
  LD_LIBRARY_PATH="$RUNTIMELIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export LD_LIBRARY_PATH
fi
REXX_PATH="$ROOT/src${RUNTIMECLASSES:+:$RUNTIMECLASSES}${REXX_PATH:+:$REXX_PATH}"
export REXX_PATH
cd "$ROOT"
"$REXX" -v | grep -q 'r13196' || { echo 'Expected ooRexx r13196' >&2; exit 2; }
"$REXX" tests/test_architecture.rex
"$REXX" tests/test_scenario_semantic_mismatch.rex
"$REXX" tests/test_jms_scenario.rex
mkdir -p "$TMP/scenarios"
"$REXX" tests/test_scenario_comparison.rex "$TMP/scenarios"
if "$REXX" tests/test_scenario_writer_existing.rex "$TMP/scenarios" >/dev/null 2>&1; then
  echo "FAIL scenario writer overwrote existing comparison" >&2; exit 1
else echo "PASS scenario writer refuses overwrite"; fi
"$REXX" tests/test_dependency_cycle.rex
"$REXX" tests/test_spot_policy.rex
"$REXX" tests/test_scope_rules_links.rex
"$REXX" tests/test_capability_placement.rex
"$REXX" tests/test_capability_relationships.rex
mkdir -p "$TMP/promotion"
"$REXX" tests/test_promotion.rex "$TMP/promotion"
"$REXX" tests/test_promotion_ssc_gate.rex
"$REXX" tests/test_ssc_receipt.rex
"$REXX" tests/test_notnotes_publication.rex
if "$REXX" tests/test_promotion.rex "$TMP/promotion" >"$TMP/promotion-overwrite.log" 2>&1; then
  echo 'FAIL promotion writer overwrote an existing record' >&2; exit 1
else echo 'PASS promotion writer refuses overwrite'; fi
for negative in test_promotion_unreviewed test_promotion_self_approval test_promotion_stale; do
  if "$REXX" "tests/${negative}.rex" >"$TMP/${negative}.log" 2>&1; then
    echo "FAIL promotion negative accepted: $negative" >&2; exit 1
  fi
  echo "PASS promotion fail-closed: $negative"
done
mkdir -p "$TMP/bundle"
"$REXX" tests/test_writer_extended.rex "$TMP/bundle"
if "$REXX" tests/test_unknown_choice.rex >/dev/null 2>&1; then
  echo 'FAIL invalid option accepted' >&2; exit 1
else echo 'PASS invalid choice rejected'; fi
if "$REXX" tests/test_bad_feature.rex >/dev/null 2>&1; then
  echo 'FAIL unknown component accepted' >&2; exit 1
else echo 'PASS unknown component rejected'; fi
if [ -n "${CONNECT_SELECTOR_ROOT:-}" ]; then
  REXX_PATH="$ROOT/src:$CONNECT_SELECTOR_ROOT/src${RUNTIMECLASSES:+:$RUNTIMECLASSES}"
  export REXX_PATH
  if [ -f "$CONNECT_SELECTOR_ROOT/CHANGELOG.md" ]; then
    "$REXX" tests/test_connect_selector_dev2.rex
  else
    "$REXX" tests/test_connect_selector_integration.rex
    "$REXX" tests/test_scenario_connect_selector.rex
    "$REXX" examples/connect_selector_choices.rex "$TMP/connect-selector-example.json"
  fi
else
  echo 'SKIP ConnectSelector integration (set CONNECT_SELECTOR_ROOT for dev1 through dev5)'
fi
if [ -n "${INTENTION_SERVICE_ROOT:-}" ]; then
  REXX_PATH="$ROOT/src:$INTENTION_SERVICE_ROOT/src:$INTENTION_SERVICE_ROOT/src/nlp${RUNTIMECLASSES:+:$RUNTIMECLASSES}"
  export REXX_PATH
  "$REXX" tests/test_intention_adapter.rex
else
  echo 'SKIP Intention Service integration (set INTENTION_SERVICE_ROOT for dev11)'
fi
"$REXX" examples/generate_plan.rex "${TMP:-/tmp}/architecture-intentions-sample.json"
"$REXX" examples/compare_cats_scenarios.rex "${TMP:-/tmp}/cats-scenarios.json"
"$REXX" examples/cats_scope_and_policies.rex "${TMP:-/tmp}/cats-discovery-plan.json"
"$REXX" examples/cats_case_and_legal_architecture.rex "${TMP:-/tmp}/cats-case-architecture.json"
echo 'PASS ooRexx r13196 architecture package qualification'
