#!/usr/bin/env bash
# test_local_roles.sh -- xtpd v0.1-dev2 role bootstrap end to end on one host.
#   "ed209k" (a): LDAP.main.  Listens; serves xtp.roles and ldap.role; runs a
#                 real ooRexx LDAP server (oorexx_ldap_identity dev9) on loopback.
#   "cats2"  (b): LDAP.spare.  Boots with an older role file, catches up from
#                 ed209k over XTP, and probes ed209k for LDAP.main.
# Mirrors grid item 1: a cats2 boot resolves ed209k as LDAP.main FRESH.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
#
# Environment: REXX_BIN, XTP_DIR, FOREIGN_RUNTIME_HOME, UNIX_SOCKET_DIR,
# PROCESS_DIR, LOGGING_DIR, CRYPTO_DIR, BOOTSTRAP_DIR, ATOMIC_FILE_DIR (built),
# LDAP_DIR, SECRET_BROKER_DIR, ALCHEMY_OBJECTS_DIR.  XTPD_TEST_CARRIER=udp|raw36.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for v in REXX_BIN XTP_DIR FOREIGN_RUNTIME_HOME UNIX_SOCKET_DIR PROCESS_DIR LOGGING_DIR CRYPTO_DIR BOOTSTRAP_DIR ATOMIC_FILE_DIR LDAP_DIR SECRET_BROKER_DIR ALCHEMY_OBJECTS_DIR; do
  if [[ -z "${!v:-}" ]]; then echo "SKIP xtpd roles ($v not set)"; exit 77; fi
done
[[ $(id -u) -eq 0 ]] || { echo "SKIP xtpd roles (needs root: STATUS and ROLE are root only)"; exit 77; }

T="$(mktemp -d /tmp/xtpd-roles.XXXXXX)"
A_PID=; B_PID=; L_PID=
cleanup() {
  for p in "$A_PID" "$B_PID" "$L_PID"; do [[ -n "$p" ]] && kill "$p" 2>/dev/null || true; done
  for _ in $(seq 1 50); do alive=0; for p in "$A_PID" "$B_PID" "$L_PID"; do [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null && alive=1; done; [[ $alive -eq 0 ]] && break; sleep 0.1; done
  for p in "$A_PID" "$B_PID" "$L_PID"; do [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null && { echo "NOTE pid $p ignored SIGTERM; killed"; kill -9 "$p" 2>/dev/null || true; }; done
 [[ -n "${KEEP:-}" ]] && echo "kept $T" || rm -rf "$T"; }
trap cleanup EXIT
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; echo "--- ed209k log"; cat "$T/a/xtpd.log" 2>/dev/null || true; echo "--- cats2 log"; cat "$T/b/xtpd.log" 2>/dev/null || true; echo "--- ldap"; cat "$T/ldap.out" 2>/dev/null || true; exit 1; }

export REXX_PATH="$ROOT/src:$XTP_DIR/rexx:$FOREIGN_RUNTIME_HOME/rexx:$UNIX_SOCKET_DIR:$PROCESS_DIR/src:$PROCESS_DIR/src/providers:$LOGGING_DIR/src:$CRYPTO_DIR/src:$BOOTSTRAP_DIR/src:$ATOMIC_FILE_DIR/src:$ATOMIC_FILE_DIR/src/providers:$LDAP_DIR:$SECRET_BROKER_DIR/src:$ALCHEMY_OBJECTS_DIR/src:$(dirname "$REXX_BIN")"
export LD_LIBRARY_PATH="$XTP_DIR/lib:$FOREIGN_RUNTIME_HOME/build:$PROCESS_DIR/native:$ATOMIC_FILE_DIR/native:$(dirname "$REXX_BIN")/../lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$(dirname "$REXX_BIN"):$PATH"
PORT=$((62000 + RANDOM % 900))
LPORT=$((61000 + RANDOM % 900))
CARRIER="${XTPD_TEST_CARRIER:-udp}"
if [[ "$CARRIER" == raw36 ]]; then
  LISTEN="3 raw36 127.0.0.1"; A_PEER="3 raw36 127.0.0.1"; B_PEER="3 raw36 127.0.0.1"
else
  LISTEN="4 udp 127.0.0.1:$PORT"; A_PEER="4 udp 127.0.0.1:$((PORT + 1))"; B_PEER="4 udp 127.0.0.1:$PORT"
fi
echo "carrier: $CARRIER"
mkdir -p "$T/a" "$T/b"
REQ() { timeout 30 "$REXX_BIN" "$ROOT/bin/xtp_request.rex" --socket "$1" "$2"; }

# service keys for the two role services, the same on both nodes
SECRET=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
for n in a b; do
  printf 'xtp.roles\t00000000000077a1\tauthenticate\tchacha20poly1305\t%s\n' "$SECRET" > "$T/$n/service.keys"
  printf 'ldap.role\t00000000000077a2\tauthenticate\tchacha20poly1305\t%s\n' "$SECRET" >> "$T/$n/service.keys"
  chmod 600 "$T/$n/service.keys"
done
# the TEST role key (stands in for the real Auth)
RKEY=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
for n in a b; do printf 'test1 %s\n' "$RKEY" > "$T/$n/role.keys"; chmod 600 "$T/$n/role.keys"; done
SEAL() { "$REXX_BIN" "$ROOT/tests/seal_role.rex" "$1" "$2" "$3" "$4"; }
R1='ROLE|LDAP|ed209k|cats2|1|1|cats1|test1'
R2='ROLE|LDAP|ed209k|cats2|2|1|cats1|test1'
SEAL "$R2" test1 "$RKEY" "$T/a/role"          # ed209k holds the newer record
SEAL "$R1" test1 "$RKEY" "$T/b/role"          # cats2 boots from an older one

# the LDAP server LDAP.main answers for
( cd "$LDAP_DIR" && exec "$REXX_BIN" "$ROOT/tests/ldap_fixture.rex" "$LPORT" "$T/ldap.ready" ) >"$T/ldap.out" 2>&1 & L_PID=$!
for _ in $(seq 1 100); do [[ -s "$T/ldap.ready" ]] && break; sleep 0.1; done
[[ -s "$T/ldap.ready" ]] || fail "LDAP fixture did not start"
pass "real ooRexx LDAP server on 127.0.0.1:$LPORT"

cat > "$T/a/services.txt" <<EOF
xtp.roles management authenticate exec $REXX_BIN $ROOT/libexec/xtp_roles.rex $T/a/role
ldap.role management authenticate exec $REXX_BIN $ROOT/libexec/ldap_role.rex $T/a/role ed209k 127.0.0.1 $LPORT
EOF
printf 'cats2 %s\n' "$A_PEER" > "$T/a/peers.txt"
cat > "$T/a/xtpd.conf" <<EOF
socket $T/a/xtpd.sock
services $T/a/services.txt
peers $T/a/peers.txt
keys $T/a/service.keys
routes $T/a/routes.tsv
listen $LISTEN
node ed209k
role_file $T/a/role
role_keys $T/a/role.keys
role_timeout_ms 1500
log $T/a/xtpd.log
EOF
: > "$T/b/services.txt"
printf 'ed209k %s\n' "$B_PEER" > "$T/b/peers.txt"
cat > "$T/b/xtpd.conf" <<EOF
socket $T/b/xtpd.sock
services $T/b/services.txt
peers $T/b/peers.txt
keys $T/b/service.keys
routes $T/b/routes.tsv
node cats2
role_file $T/b/role
role_keys $T/b/role.keys
role_timeout_ms 1500
log $T/b/xtpd.log
EOF

"$REXX_BIN" "$ROOT/bin/xtpd.rex" "$T/a/xtpd.conf" 2>"$T/a/stderr" & A_PID=$!
for _ in $(seq 1 100); do grep -q 'running:' "$T/a/xtpd.log" 2>/dev/null && break; sleep 0.1; done
grep -q 'running:' "$T/a/xtpd.log" || fail "ed209k xtpd did not start: $(tail -3 "$T/a/stderr")"
"$REXX_BIN" "$ROOT/bin/xtpd.rex" "$T/b/xtpd.conf" 2>"$T/b/stderr" & B_PID=$!
for _ in $(seq 1 150); do grep -q 'role: source' "$T/b/xtpd.log" 2>/dev/null && break; sleep 0.1; done
grep -q 'role: source' "$T/b/xtpd.log" || fail "cats2 never reported its role: $(tail -3 "$T/b/stderr")"
pass "both daemons running; cats2 reported its role at boot"

grep -q 'role: verifier TEST_ONLY_HMAC' "$T/b/xtpd.log" || fail "the test-only verifier was not declared in the log"
pass "the log says the role verifier is test-only"
grep -q 'role: fetched .* bytes from ed209k' "$T/b/xtpd.log" || fail "cats2 did not fetch the role from ed209k over xtp.roles"
grep -q 'KIND=ROLE_CHANGE_PUBLISHED' "$T/b/xtpd.log" || fail "cats2 did not publish the newer record"
cmp -s "$T/a/role" "$T/b/role" || fail "cats2's role file is not ed209k's newer envelope"
pass "catch-up: cats2 fetched epoch 2 over XTP, verified it, published it durably"
grep -q 'role: source ROLE_SOURCE status FRESH peer ed209k epoch 2 version 1 ready yes' "$T/b/xtpd.log" || fail "cats2 boot did not resolve ed209k as LDAP.main FRESH"
grep -q 'role: probe of MAIN ed209k at 2.1 protection authenticate -> CONFIRM ed209k MAIN 2 1' "$T/b/xtpd.log" || fail "the probe answer is not the authenticated CONFIRM"
pass "boot: cats2 resolves ed209k as LDAP.main FRESH, by an authenticated probe of a live LDAP server"
OUT=$(REQ "$T/b/xtpd.sock" STATUS) || fail "STATUS: $OUT"
[[ "$OUT" == *"role source ROLE_SOURCE status FRESH peer ed209k epoch 2 version 1 ready yes"* ]] || fail "STATUS line: $OUT"
pass "STATUS carries the role: $OUT"

# LDAP down: the record still names ed209k, but nothing confirms it
kill "$L_PID"; wait "$L_PID" 2>/dev/null || true; L_PID=
OUT=$(REQ "$T/b/xtpd.sock" ROLE) || fail "ROLE: $OUT"
[[ "$OUT" == *"status UNAVAILABLE"*"ready no"* ]] || fail "with LDAP down, ROLE said: $OUT"
grep -q -- '-> DENY LDAP_DOWN' "$T/b/xtpd.log" || fail "the probe did not report LDAP_DOWN"
pass "LDAP down: ROLE is UNAVAILABLE, not READY (never FRESH from the file alone)"

( cd "$LDAP_DIR" && exec "$REXX_BIN" "$ROOT/tests/ldap_fixture.rex" "$LPORT" "$T/ldap.ready2" ) >>"$T/ldap.out" 2>&1 & L_PID=$!
for _ in $(seq 1 100); do [[ -s "$T/ldap.ready2" ]] && break; sleep 0.1; done
OUT=$(REQ "$T/b/xtpd.sock" ROLE) || fail "ROLE: $OUT"
[[ "$OUT" == *"status FRESH peer ed209k"*"ready yes"* ]] || fail "after LDAP returned, ROLE said: $OUT"
pass "LDAP back: ROLE is FRESH again"

# a forged newer record on ed209k (wrong key): refused, and not confirmed
SEAL 'ROLE|LDAP|ed209k|cats2|3|1|cats1|test1' test1 "$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')" "$T/a/role"
OUT=$(REQ "$T/b/xtpd.sock" ROLE) || true
grep -q 'KIND=ROLE_BAD_SIGNATURE' "$T/b/xtpd.log" || fail "the forged record was not refused for its signature"
[[ "$(head -c 40 "$T/b/role")" == "ROLE|LDAP|ed209k|cats2|2|1|cats1|test1"* ]] || fail "cats2's role file changed after a forged offer"
[[ "$OUT" == *"status UNAVAILABLE"*"ready no"* ]] || fail "after a forged record, ROLE said: $OUT"
grep -q -- '-> DENY RECORD_DIFFERS' "$T/b/xtpd.log" || fail "ed209k's probe did not deny a record it does not hold"
pass "forged newer record: refused (bad signature), file unchanged, not FRESH"

# the hooks run only on an authenticated session; no TCP listener belongs to xtpd
if ss -ltnp 2>/dev/null | grep -E "pid=($A_PID|$B_PID)," >/dev/null; then fail "an xtpd process holds a TCP listener"; fi
pass "no xtpd process holds a TCP listener"
# both daemons stop on SIGTERM (dev2 found an interrupt swallowed by a role trap)
kill "$A_PID" "$B_PID"
for _ in $(seq 1 50); do kill -0 "$A_PID" 2>/dev/null || kill -0 "$B_PID" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$A_PID" 2>/dev/null || kill -0 "$B_PID" 2>/dev/null; then fail "a daemon ignored SIGTERM"; fi
A_PID=; B_PID=
pass "both daemons stopped on SIGTERM within 5 s"
echo "PASS xtpd roles end to end over $CARRIER"
