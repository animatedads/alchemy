#!/usr/bin/env bash
set -euo pipefail
: "${ED209_GRID_SOURCE:?set Grid source tree for native test}"
: "${ED209_REXX:?set tested ooRexx interpreter}"
: "${ED209_REXX_LIB:?set ooRexx native lib directory}"
W=$(cd "$(dirname "$0")/.." && pwd)
G=$ED209_GRID_SOURCE R=$ED209_REXX
T=$(mktemp -d);trap 'rm -rf "$T"' EXIT
KEY=$(python3 -c 'print("ab"*32)')  # disposable fixture, NEVER a commissioned credential
export REXX_PATH="$W/rexx:$G/rto2:$G/grid:$G/deps:$G/deps/qf:$G/deps/alchemy:$G/deps/socket-provider-dev14/src:$G/xtp/upstream-dev18/rexx:${REXX_PATH:-}"
export LD_LIBRARY_PATH="$ED209_REXX_LIB:$G/deps/fast/build:$G/xtp/upstream-dev18/lib:${LD_LIBRARY_PATH:-}"
printf 'GRID.MU.MU-ED209F|grid-controller|k1|%s|l2|02:52:00:09:00:01|RTO2.MN1-ED209F|GRID.RTO2.MN1-ED209F|GRID\n' "$KEY" > "$T/manifest"
request(){ "$R" "$W/tests/wire_fixture.rex" request "$T/req" "$T/resp" "$KEY" "$1"; }
serve(){ QF_XTP_REQUEST_FILE="$T/req" QF_XTP_CARRIER=l2 QF_XTP_SOURCE=02:52:00:09:00:01 QF_XTP_MANAGER_NAME=GRID.MN.MN1-ED209F QF_XTP_PEERS="$T/manifest" QF_XTP_ROOT="$T/qf" QF_XTP_RTO2_ENABLED="$1" GRID_MU_ID=MU-ED209F GRID_NODE_ID=MN1-ED209F "$R" "$W/rexx/qf-xtp-handler.rto2.rex" > "$T/resp"; }
request normal
serve 1
"$R" "$W/tests/wire_fixture.rex" response "$T/req" "$T/resp" "$KEY"
if [[ ${ED209_EXTENDED_CRYPTO_TESTS:-0} != 1 ]]; then
  echo "PASS native ooRexx authenticated RTO2 work and capture (extended crypto negatives not run)"
  exit 0
fi
request normal
serve 0
"$R" "$W/tests/wire_fixture.rex" reject "$T/req" "$T/resp" "$KEY" RTO2_WORK_DISABLED
request wrong-target
serve 1
"$R" "$W/tests/wire_fixture.rex" reject "$T/req" "$T/resp" "$KEY" RTO2_CONTROLLER_BINDING_DENIED
request out-of-bounds
serve 1
"$R" "$W/tests/wire_fixture.rex" reject "$T/req" "$T/resp" "$KEY" RTO2_WORK_BOUNDS
echo 'PASS native ooRexx RTO2 authenticated controller/MI exchange suite'
