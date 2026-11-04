#!/usr/bin/env bash
# dev33: a protected message sent to an older listener (PEER_ROOT) is refused
# there, not delivered as if its protected bytes were the message.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).  Without PEER_ROOT the test is skipped.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PEER_ROOT=${PEER_ROOT:-}
PLANNER=${OPERATIONAL_PLANNER_DIR:-$ROOT/../oorexx_operational_degradation_planner_v0.1-dev5}
if [[ -z "$PEER_ROOT" ]]; then echo "SKIP protected message to an older listener (set PEER_ROOT)"; exit 0; fi
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
PEER_CRYPTO=""; nm "$PEER_ROOT/lib/libxtp.a" 2>/dev/null | grep -q EVP_ && PEER_CRYPTO=-lcrypto
g++ -I"$PEER_ROOT/include" -O2 -std=c++17 -pthread -o "$OUT/rx" "$ROOT/tests/tools/interop_msg_receiver.cpp" "$PEER_ROOT/lib/libxtp.a" "$PLANNER/lib/liboperational_planner.a" -lcrypto || exit 2
g++ -I"$ROOT/include" -O2 -std=c++17 -pthread -o "$OUT/tx" "$ROOT/tests/tools/interop_protected_sender.cpp" "$ROOT/lib/libxtp.a" "$PLANNER/lib/liboperational_planner.a" -lcrypto || exit 2
PORT=$((47900 + RANDOM % 50))
"$OUT/rx" $PORT >"$OUT/rx.out" 2>"$OUT/rx.err" & RX=$!
sleep 0.3
TX="$("$OUT/tx" $PORT 2>/dev/null)"; wait $RX
RXO="$(grep -v READY "$OUT/rx.out")"
echo "  sender: $TX"
echo "  older listener: $RXO"
if [[ "$TX" == REFUSED* && "$RXO" == NOTHING* ]]; then echo "PASS protected message to an older listener: refused there, nothing delivered"; exit 0; fi
echo "FAIL protected message to an older listener"; exit 1
