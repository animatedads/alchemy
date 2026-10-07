#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${OOREXX_ROOT:=/usr/local}"
: "${RTP_ROOT:=$(cd "$ROOT/.." && pwd)/oorexx_rtp_v0.1-dev2}"
: "${SOCKET_PROVIDER_ROOT:=$(cd "$ROOT/.." && pwd)/oorexx_socket_provider_v0.1-dev9}"
: "${PYTHON:=python3}"

if [[ ! -x "$OOREXX_ROOT/bin/rexx" ]]; then
  echo "FAIL: ooRexx runtime not found at $OOREXX_ROOT/bin/rexx" >&2
  exit 2
fi
if [[ ! -f "$RTP_ROOT/Makefile" ]]; then
  echo "FAIL: shared RTP root not found: $RTP_ROOT" >&2
  exit 3
fi
if [[ ! -f "$SOCKET_PROVIDER_ROOT/src/SocketProvider.cls" ]]; then
  echo "FAIL: Socket Provider root not found: $SOCKET_PROVIDER_ROOT" >&2
  exit 3
fi

echo "== build shared RTP =="
make -C "$RTP_ROOT" clean all OOREXX_ROOT="$OOREXX_ROOT"

echo "== build SIP =="
make -C "$ROOT" clean all OOREXX_ROOT="$OOREXX_ROOT"

export LD_LIBRARY_PATH="$ROOT/build:$RTP_ROOT/build:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/tests/logging_stub:$RTP_ROOT/src:$SOCKET_PROVIDER_ROOT/src${REXX_PATH:+:$REXX_PATH}"

echo "== shared socket ownership boundary =="
if grep -Eq 'SockSocket|SockBind|SockSendTo|SockRecvFrom' "$ROOT/src/sip.cls"; then
  echo "FAIL: SIP source bypasses SocketProvider" >&2
  exit 6
fi
if grep -Eq 'sys/socket.h|sendto\(|recvfrom\(|socket\(' "$RTP_ROOT/native/oorexx_rtp.cpp"; then
  echo "FAIL: RTP native layer owns carrier socket" >&2
  exit 7
fi
echo "PASS shared socket ownership boundary"

echo "== shared RTP object/lifecycle probe =="
(
  cd "$RTP_ROOT"
  "$OOREXX_ROOT/bin/rexx" tests/shared_rtp_probe.rex
)

echo "== captured Twinkle REGISTER =="
(
  cd "$ROOT/tests"
  "$OOREXX_ROOT/bin/rexx" twinkle_register_fixture.rex
)

echo "== captured Twinkle OPTIONS =="
(
  cd "$ROOT/tests"
  "$OOREXX_ROOT/bin/rexx" twinkle_options_fixture.rex
)

echo "== registrar inspector =="
(
  cd "$ROOT/tests"
  "$OOREXX_ROOT/bin/rexx" registration_inspector_probe.rex
)

echo "== SIP logging observability =="
(
  cd "$ROOT/tests"
  "$OOREXX_ROOT/bin/rexx" logging_observability_probe.rex
  "$OOREXX_ROOT/bin/rexx" logging_auth_trace_probe.rex
)

echo "== independent lifecycle =="
(
  cd "$ROOT/tests"
  "$OOREXX_ROOT/bin/rexx" peer_lifecycle_probe.rex
)

echo "== real INVITE + shared RTP media graph =="
server_log=$(mktemp)
client_log=$(mktemp)
cleanup() {
  if [[ -n "${server_pid:-}" ]]; then kill "$server_pid" 2>/dev/null || true; fi
  rm -f "$server_log" "$client_log"
}
trap cleanup EXIT
(
  cd "$ROOT/tests"
  "$OOREXX_ROOT/bin/rexx" media_object_graph_server.rex
) >"$server_log" 2>&1 &
server_pid=$!
for _ in $(seq 1 60); do
  if grep -q '^READY 5099' "$server_log"; then break; fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$server_log"
    echo "FAIL: media server exited before READY" >&2
    exit 4
  fi
  sleep 0.1
done
if ! grep -q '^READY 5099' "$server_log"; then
  cat "$server_log"
  echo "FAIL: media server did not become ready" >&2
  exit 5
fi
"$PYTHON" "$ROOT/tests/send_invite_rtp.py" 5099 >"$client_log" 2>&1
wait "$server_pid"
server_pid=""
cat "$client_log"
cat "$server_log"
grep -q '^OBJECTS SIPCALLCONTROL SIPINBOUNDAUDIO SIPOUTBOUNDAUDIO RTPRECEIVER RTPSENDER' "$server_log"
grep -q '^FRAME 320 160 8000 S16LE 0 ' "$server_log"
grep -q '^CONSUMERS 1 1 3' "$server_log"
grep -q '^BROKEN_ERROR_PRESENT 1' "$server_log"
grep -q '^PRODUCER_COUNTS 1 1' "$server_log"

trap - EXIT
cleanup

echo "PASS environment qualification: SIP signalling + shared RTP layer"
