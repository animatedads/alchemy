#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

# Use an explicit runtime, including the user-supplied extracted .deb root.
if [ -n "${OOREXX_RUNTIME_ROOT:-}" ]; then
  runtime="${OOREXX_RUNTIME_ROOT%/}/usr/local"
  [ -x "$runtime/bin/rexx" ] || { echo 'ERROR: invalid OOREXX_RUNTIME_ROOT' >&2; exit 2; }
  REXX="${REXX:-$runtime/bin/rexx}"
  LD_LIBRARY_PATH="$runtime/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" export LD_LIBRARY_PATH
  REXX_PATH="$runtime/bin${REXX_PATH:+:$REXX_PATH}" export REXX_PATH
else
  REXX="${REXX:-rexx}"
fi
REXX_PATH="$PWD/src:$PWD/optional${REXX_PATH:+:$REXX_PATH}" export REXX_PATH

for case in smoke civil_resolution tzif_provider iso_civil edge_zones rejections tzif_binary recurrence recurrence_rejects time_events events_rejects authority_journal authority_rejections impact_analysis impact_folds impact_watch rule_snapshots change_publication validity_window; do
  "$REXX" "tests/$case.rex"
done
"$REXX" examples/london_sydney.rex
"$REXX" examples/recurring_wall_time.rex
"$REXX" examples/school_dinner.rex
"$REXX" examples/impact_change.rex

# Integration qualification is explicit and all-or-nothing. No blind
# search for arbitrary or conflicting dependency revisions in the tree.
if [ -n "${TIME_CONNECT_ROOT:-}${TIME_RPC_CORE_ROOT:-}${TIME_JSONRPC_ROOT:-}" ]; then
  [ -n "${TIME_CONNECT_ROOT:-}" ] && [ -n "${TIME_RPC_CORE_ROOT:-}" ] && [ -n "${TIME_JSONRPC_ROOT:-}" ] || {
    echo 'ERROR: provide TIME_CONNECT_ROOT, TIME_RPC_CORE_ROOT, TIME_JSONRPC_ROOT together' >&2; exit 2;
  }
  for path in "$TIME_CONNECT_ROOT/src/ConnectSelector.cls" "$TIME_RPC_CORE_ROOT/src/RpcServiceCore.cls" "$TIME_JSONRPC_ROOT/src/JsonRpcFabric.cls"; do
    [ -f "$path" ] || { echo "ERROR: missing exact dependency $path" >&2; exit 2; }
  done
  REXX_PATH="$REXX_PATH:$TIME_CONNECT_ROOT/src:$TIME_RPC_CORE_ROOT/src:$TIME_JSONRPC_ROOT/src" export REXX_PATH
  "$REXX" tests/endpoint_integration.rex
  "$REXX" tests/json_rpc_integration.rex
  "$REXX" tests/event_endpoint.rex
  "$REXX" tests/event_json_rpc.rex
  "$REXX" tests/authority_transport.rex
  "$REXX" tests/impact_endpoint.rex
fi
