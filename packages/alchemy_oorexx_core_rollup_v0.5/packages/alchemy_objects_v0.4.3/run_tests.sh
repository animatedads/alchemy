#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CRYPTO_INPUT=${1:-${OOREXX_CRYPTO_SRC:-}}

usage() {
  echo "usage: $0 /path/to/oorexx_crypto_v0.1/src" >&2
  echo "       $0 /path/to/oorexx_crypto_v0.1/src/crypto.cls" >&2
  echo "" >&2
  echo "optional interpreter override:" >&2
  echo "  OOREXX_REXX=/path/to/rexx $0 ..." >&2
  echo "  REXX=/path/to/rexx $0 ...        (compatibility)" >&2
  echo "" >&2
  echo "to time the complete suite, wrap the runner itself:" >&2
  echo "  time $0 /path/to/oorexx_crypto_v0.1/src" >&2
  exit 2
}

[ -n "$CRYPTO_INPUT" ] || usage

# Accept either the documented source directory or crypto.cls itself.
# Canonicalize before changing into tests/: a relative dependency path that is
# valid from the package root must not change meaning after cd.
if [ -f "$CRYPTO_INPUT" ]; then
  [ "$(basename -- "$CRYPTO_INPUT")" = "crypto.cls" ] || usage
  CRYPTO_SRC=$(CDPATH= cd -- "$(dirname -- "$CRYPTO_INPUT")" && pwd)
elif [ -d "$CRYPTO_INPUT" ]; then
  CRYPTO_SRC=$(CDPATH= cd -- "$CRYPTO_INPUT" && pwd)
else
  usage
fi

[ -f "$CRYPTO_SRC/crypto.cls" ] || usage

# REXX/OOREXX_REXX is an executable path/name, not a shell command line.
# In particular, REXX="time rexx" cannot work safely with argv-preserving
# execution. Time this script externally instead.
REXX_INPUT=${OOREXX_REXX:-${REXX:-rexx}}
case "$REXX_INPUT" in
  *[[:space:]]*)
    echo "error: ooRexx interpreter override must name one executable, not a command line: $REXX_INPUT" >&2
    echo "hint: use 'time $0 ...' to time the suite" >&2
    exit 2
    ;;
esac

if [ -x "$REXX_INPUT" ] && [ "${REXX_INPUT#/}" != "$REXX_INPUT" ]; then
  REXX_BIN="$REXX_INPUT"
elif command -v "$REXX_INPUT" >/dev/null 2>&1; then
  REXX_BIN=$(command -v "$REXX_INPUT")
else
  echo "error: ooRexx interpreter not found: $REXX_INPUT" >&2
  exit 2
fi

export REXX_PATH="$ROOT/tests:$ROOT/src:$ROOT/inspector:$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT/tests"
run() { echo ">>> $*"; "$@"; }
run "$REXX_BIN" test_load.rex
run "$REXX_BIN" test_base.rex
run "$REXX_BIN" test_security_runtime_probe.rex "$ROOT/tests/security_agent.rex"
run "$REXX_BIN" test_security_manager_contract.rex "$ROOT/tests/security_agent.rex"
run "$REXX_BIN" test_security_capability_method.rex "$ROOT/tests/capability_agent.rex"
run "$REXX_BIN" test_security_requires_gap.rex "$ROOT/tests/requires_agent.rex"
run "$REXX_BIN" test_security_manager_immutability.rex "$ROOT/tests/escape_agent.rex"
# ooRexx command-line program arguments arrive as one string; keep both paths in one argument.
run "$REXX_BIN" test_composite_policy.rex "$ROOT/tests/command_agent.rex $ROOT/tests/security_agent.rex"
run "$REXX_BIN" test_method_telemetry.rex
run "$REXX_BIN" test_capability_expiry.rex
run "$REXX_BIN" test_trace_compliance_data.rex
run "$REXX_BIN" test_test_support.rex
run "$REXX_BIN" test_security_quota.rex "$ROOT/tests/quota_agent.rex"
run "$REXX_BIN" test_locked_method.rex
run "$REXX_BIN" test_locked_method_security_manager.rex "$ROOT/tests/locked_method_agent.rex"
run "$REXX_BIN" test_locked_method_envelope.rex
run "$REXX_BIN" test_method_policy_relationships.rex
run "$REXX_BIN" test_requirements_instrumentation_rules.rex
run "$REXX_BIN" test_protected_policy_mutations.rex "$ROOT/tests/policy_mutation_agent.rex"
run "$REXX_BIN" test_inspector_key_boundary.rex
# Run the Clouseau/forensic stress cases last; each test remains a separate ooRexx process.
run "$REXX_BIN" test_inspector_bridge.rex
run "$REXX_BIN" test_full_snapshot.rex
