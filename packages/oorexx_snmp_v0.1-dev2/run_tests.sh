#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_HOME:=/usr/local}"
EVENT_RUNTIME="${EVENT_RUNTIME:-}"
OBSERVATION_RUNTIME="${OBSERVATION_RUNTIME:-}"
if [[ -z "$EVENT_RUNTIME" ]]; then
  echo "EVENT_RUNTIME must point to the directory containing EventRuntime.cls" >&2
  exit 2
fi
export PATH="$OOREXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib:${LD_LIBRARY_PATH:-}"
export REXX_PATH="$ROOT/src:$EVENT_RUNTIME:$OOREXX_HOME/bin:$OOREXX_HOME/share/ooRexx:${REXX_PATH:-}"
cd "$ROOT/tests"
for t in \
  test_unknown_projection.rex \
  test_table_projection.rex \
  test_events.rex \
  test_notification.rex \
  test_map_layering.rex \
  test_alias_projection.rex \
  test_table_enumeration.rex \
  test_semantic_rules.rex \
  test_notification_state.rex \
  test_schema_compat.rex; do
  echo "== $t =="
  rexx "$t"
done
if [[ -n "$OBSERVATION_RUNTIME" ]]; then
  export REXX_PATH="$ROOT/src:$EVENT_RUNTIME:$OBSERVATION_RUNTIME:$OOREXX_HOME/bin:$OOREXX_HOME/share/ooRexx:${REXX_PATH:-}"
  echo "== test_observation.rex =="
  rexx test_observation.rex
else
  echo "== test_observation.rex == SKIP (OBSERVATION_RUNTIME not supplied)"
fi
