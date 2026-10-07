#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
REXXC_BIN="${REXXC_BIN:-rexxc}"
command -v "$REXX_BIN" >/dev/null 2>&1 || { echo "FAIL: ooRexx executable '$REXX_BIN' not found"; exit 20; }
"$REXX_BIN" -v || true

if command -v "$REXXC_BIN" >/dev/null 2>&1; then
  while IFS= read -r src; do "$REXXC_BIN" "$src"; done < <(find "$ROOT/src" "$ROOT/tests" "$ROOT/examples" -type f \( -name '*.cls' -o -name '*.rex' \) | sort)
else
  echo "SKIP rexxc: '$REXXC_BIN' not found"
fi

export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT/tests"
for test in \
  test_socket_provider.rex \
  test_tls_boundary.rex \
  test_tls_family_scheme.rex \
  test_socket_intentions.rex \
  test_socket_intention_open.rex \
  test_xtp_dev9_negotiation.rex \
  test_xtp_dev10_negotiation.rex \
  test_xtp_dev12_capability_truth.rex \
  test_xtp_dev14_capability_truth.rex \
  test_xtp_dev17_capability_truth.rex \
  test_xtp_dev10_intention_open.rex \
  test_dynamic_socket_intention_discovery.rex \
  test_dynamic_xtp_capability_refresh.rex \
  test_norm_negotiation.rex \
  test_norm_dev3_negotiation.rex \
  test_multicast_membership_contract.rex \
  test_udp_multicast_contract.rex \
  test_descriptor_readiness_contract.rex \
  test_collision_merge_dev12.rex; do
  "$REXX_BIN" "$test"
done

echo 'PASS Socket Provider dev13 merged contract suite'

if [[ "${RUN_REAL_RXSOCK_UDP:-0}" == "1" ]]; then
  "$REXX_BIN" test_udp_datagram_provider.rex
fi
if [[ "${RUN_REAL_RXSOCK_TCP:-0}" == "1" ]]; then
  : "${RXSOCK_SRC:?RXSOCK_SRC must point to directory containing socket.cls}"
  export REXX_PATH="$ROOT/src:$RXSOCK_SRC${REXX_PATH:+:$REXX_PATH}"
  "$REXX_BIN" test_real_tcp.rex
fi
if [[ "${RUN_REAL_UNIX_SOCKET:-0}" == "1" ]]; then
  : "${UNIX_SOCKET_SRC:?UNIX_SOCKET_SRC must point to ooRexx Unix Socket v0.6}"
  : "${FOREIGN_RUNTIME_SRC:?FOREIGN_RUNTIME_SRC must point to Foreign Runtime source}"
  export REXX_PATH="$ROOT/src:$UNIX_SOCKET_SRC:$FOREIGN_RUNTIME_SRC/rexx${REXX_PATH:+:$REXX_PATH}"
  export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_SRC/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  "$REXX_BIN" test_real_unix.rex
fi

if [[ "${RUN_XTP_DEV14_ADAPTER_CONTRACT:-0}" == "1" ]]; then
  "$REXX_BIN" test_xtp_dev14_provider_merge.rex
fi
