#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REXX=${REXX:-rexx}
REXXC=${REXXC:-rexxc}
: "${ALCHEMY_OBJECTS_SRC:?ALCHEMY_OBJECTS_SRC must point to alchemy_objects_v0.8/src}"
: "${CRYPTO_SRC:?CRYPTO_SRC must point to oorexx_crypto_v0.1/src}"
: "${JOURNAL_POINTED_STATE_SRC:?JOURNAL_POINTED_STATE_SRC must point to oorexx_journal_pointed_state_v0.1/src}"
[[ -d "$ALCHEMY_OBJECTS_SRC" ]]
[[ -d "$CRYPTO_SRC" ]]
[[ -d "$JOURNAL_POINTED_STATE_SRC" ]]
export REXX_PATH="$HERE/src:$ALCHEMY_OBJECTS_SRC:$CRYPTO_SRC:$JOURNAL_POINTED_STATE_SRC:${REXX_PATH:-}"
WORK="$HERE/.test-run.$$"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
mkdir -p "$WORK"
cp "$HERE"/src/*.cls "$WORK"/
cp "$HERE"/tests/*.rex "$WORK"/
cp "$HERE"/tests/*.json "$WORK"/ 2>/dev/null || true
cd "$WORK"

for f in *.cls *.rex; do
  "$REXXC" "$f" >/dev/null
done

if [[ -d "$HERE/tools" ]]; then
  while IFS= read -r tool; do
    (cd "$HERE/tools" && "$REXXC" "$(basename "$tool")" >/dev/null)
  done < <(find "$HERE/tools" -maxdepth 1 -type f -name '*.rex' | sort)
fi

for t in \
  test_alchemy_base_integration.rex \
  test_alchemy_reference_boundary.rex \
  test_terminal_core.rex \
  test_terminal_emulator_journal.rex \
  test_terminal_emulator_timeline.rex \
  test_terminal_emulator_execution_boundary.rex \
  test_terminal_emulator_orchestration.rex \
  test_terminal_emulator_journal_alchemy.rex \
  test_known_state.rex \
  test_known_state_tracker.rex \
  test_terminal5250.rex \
  test_tn5250_device_identity.rex \
  test_tn5250_wire.rex \
  test_tn5250_devname_collision.rex \
  test_tn5250_live_session.rex \
  test_terminal_ownership.rex \
  test_tn5250_session_ownership.rex \
  test_terminal_broker.rex \
  test_tn5250_broker_boundary.rex \
  test_terminal_broker_protocol.rex \
  test_terminal_broker_socket.rex \
  test_terminal_broker_service.rex \
  test_terminal_broker_operations.rex \
  test_terminal_control_gate.rex \
  test_terminal_swap.rex \
  test_known_state_json.rex \
  test_known_state_5250.rex \
  test_known_state_password_change.rex \
  test_live_known_state_fixture.rex \
  test_credential_login.rex \
  test_password_change_stage.rex \
  test_password_expiry_flow_order.rex \
  test_main_menu_signoff.rex \
  test_broker_orderly_signoff.rex \
  test_5250_datastream.rex \
  test_5250_pending_aid.rex \
  test_5250_query.rex \
  test_5250_immediate_alt.rex \
  test_5250_operator_error_host.rex \
  test_field_navigation_operator_error.rex \
  test_tn5250_display_driver.rex \
  test_tn5250_control.rex \
  test_tn5250_save_restore.rex \
  test_tn5250_input_wire.rex \
  test_tn5250_vertical.rex; do
  echo "=== $t ==="
  "$REXX" "$t"
done

echo "=== test_terminal_broker_socket.sh ==="
REXX="$REXX" bash "$HERE/tests/test_terminal_broker_socket.sh"

echo "=== test_terminal_broker_socket_service.sh ==="
REXX="$REXX" bash "$HERE/tests/test_terminal_broker_socket_service.sh"

echo "=== test_terminal_broker_operations_service.sh ==="
REXX="$REXX" bash "$HERE/tests/test_terminal_broker_operations_service.sh"

if [[ -n "${WLU_SRC:-}" ]]; then
  echo "=== test_terminal_control_wlu.rex ==="
  REXX_PATH="$REXX_PATH:$WLU_SRC" "$REXX" test_terminal_control_wlu.rex
else
  echo "SKIP test_terminal_control_wlu.rex (set WLU_SRC for external integration)"
fi

if command -v python3 >/dev/null 2>&1; then
  portfile="$WORK/loopback.port"
  python3 - "$portfile" <<'PY' &
import socket, sys
portfile=sys.argv[1]
s=socket.socket()
s.bind(('127.0.0.1',0))
with open(portfile,'w') as f:
    f.write(str(s.getsockname()[1])); f.flush()
s.listen(1)
c,_=s.accept()
data=c.recv(1024)
c.sendall(b'ACK:'+data)
c.close(); s.close()
PY
  server=$!
  for _ in $(seq 1 100); do
    [[ -s "$portfile" ]] && break
    sleep 0.02
  done
  port=$(cat "$portfile")
  echo "=== test_tcp_transport.rex ==="
  "$REXX" test_tcp_transport.rex "$port"
  wait "$server"
else
  echo "SKIP test_tcp_transport.rex (python3 unavailable for loopback fixture)"
fi


if command -v openssl >/dev/null 2>&1 && command -v socat >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  tlsdir="$WORK/tls-fixture"
  mkdir -p "$tlsdir"
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$tlsdir/key.pem" -out "$tlsdir/cert.pem" -days 1 \
    -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost' >/dev/null 2>&1
  tlsport=$(python3 - <<'PYPORT'
import socket
s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()
PYPORT
)
  socat OPENSSL-LISTEN:"$tlsport",reuseaddr,cert="$tlsdir/cert.pem",key="$tlsdir/key.pem",verify=0 EXEC:/bin/cat >"$tlsdir/server.log" 2>&1 &
  tlsserver=$!
  sleep 0.1
  echo "=== test_tls_transport.rex ==="
  "$REXX" test_tls_transport.rex "$tlsport" "$tlsdir/cert.pem"
  wait "$tlsserver" || true

  tlsport2=$(python3 - <<'PYPORT2'
import socket
s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()
PYPORT2
)
  socat OPENSSL-LISTEN:"$tlsport2",reuseaddr,cert="$tlsdir/cert.pem",key="$tlsdir/key.pem",verify=0 EXEC:/bin/cat >"$tlsdir/server2.log" 2>&1 &
  tlsserver2=$!
  sleep 0.1
  echo "=== test_tls_helper_lifecycle.rex ==="
  "$REXX" test_tls_helper_lifecycle.rex "$tlsport2" "$tlsdir/cert.pem"
  kill "$tlsserver2" >/dev/null 2>&1 || true
  wait "$tlsserver2" || true
else
  echo "SKIP test_tls_transport.rex (openssl/socat/python3 fixture unavailable)"
fi
