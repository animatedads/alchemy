#!/usr/bin/env bash
# test_local_ssh.sh -- xtpd v0.1-dev1 end to end on one host:
#   real OpenSSH client -> ProxyUseFdpass -> xtp_request.rex -> xtpd "ed209k"
#   -> XTP session (UDP loopback, encrypted with a service key) -> xtpd "cats1"
#   -> exec hook /usr/sbin/sshd -i -> a shell.
# Nothing listens on TCP at any point.  Needs root (sshd -i, its host key).
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026.
#
# Environment: REXX_BIN, XTP_DIR (built oorexx_xtp dev38+), FOREIGN_RUNTIME_HOME,
# UNIX_SOCKET_DIR, PROCESS_DIR (oorexx_process dev2+), LOGGING_DIR (oorexx_logging v0.7).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for v in REXX_BIN XTP_DIR FOREIGN_RUNTIME_HOME UNIX_SOCKET_DIR PROCESS_DIR LOGGING_DIR; do
  if [[ -z "${!v:-}" ]]; then echo "SKIP xtpd local ssh ($v not set)"; exit 77; fi
done
[[ $(id -u) -eq 0 ]] || { echo "SKIP xtpd local ssh (needs root for sshd -i)"; exit 77; }
command -v ssh >/dev/null && [[ -x /usr/sbin/sshd ]] || { echo "SKIP xtpd local ssh (no OpenSSH)"; exit 77; }

T="$(mktemp -d /tmp/xtpd-test.XXXXXX)"
A_PID=; B_PID=
cleanup() { [[ -n "$A_PID" ]] && kill "$A_PID" 2>/dev/null || true; [[ -n "$B_PID" ]] && kill "$B_PID" 2>/dev/null || true; sleep 0.5; [[ -n "${KEEP:-}" ]] && echo "kept $T" || rm -rf "$T"; }
trap cleanup EXIT
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; echo "--- cats1 log"; cat "$T/a/xtpd.log" 2>/dev/null || true; echo "--- ed209k log"; cat "$T/b/xtpd.log" 2>/dev/null || true; exit 1; }

export REXX_PATH="$ROOT/src:$XTP_DIR/rexx:$FOREIGN_RUNTIME_HOME/rexx:$UNIX_SOCKET_DIR:$PROCESS_DIR/src:$PROCESS_DIR/src/providers:$LOGGING_DIR/src:$(dirname "$REXX_BIN")"
export LD_LIBRARY_PATH="$XTP_DIR/lib:$FOREIGN_RUNTIME_HOME/build:$PROCESS_DIR/native:$(dirname "$REXX_BIN")/../lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$(dirname "$REXX_BIN"):$PATH"
PORT=$((62000 + RANDOM % 900))
# XTPD_TEST_CARRIER=raw36 runs the same test over raw IP protocol 36 on loopback (the field carrier)
CARRIER="${XTPD_TEST_CARRIER:-udp}"
if [[ "$CARRIER" == raw36 ]]; then
  LISTEN="3 raw36 127.0.0.1"; A_PEER="3 raw36 127.0.0.1"; B_PEER="3 raw36 127.0.0.1"
else
  LISTEN="4 udp 127.0.0.1:$PORT"; A_PEER="4 udp 127.0.0.1:$((PORT + 1))"; B_PEER="4 udp 127.0.0.1:$PORT"
fi
echo "carrier: $CARRIER"

mkdir -p "$T/a" "$T/b" "$T/ssh" /run/sshd
# the fence stand-in: records what the helper would have run
cat > "$T/fake-nft" <<EOF
#!/bin/sh
echo "\$*" >> "$T/nft.calls"
EOF
chmod 755 "$T/fake-nft"
export XTPD_NFT="$T/fake-nft"

# one service key, the same on both nodes (mode 600, owned by this user)
SECRET=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
for n in a b; do
  printf 'ssh.management\t00000000000055a1\tencrypt\tchacha20poly1305\t%s\n' "$SECRET" > "$T/$n/service.keys"
  chmod 600 "$T/$n/service.keys"
done

# sshd for the hook: its own host key and authorized key, no listener (-i)
ssh-keygen -q -t ed25519 -N '' -f "$T/ssh/host_key"
ssh-keygen -q -t ed25519 -N '' -f "$T/ssh/client_key"
cp "$T/ssh/client_key.pub" "$T/ssh/authorized_keys"
cat > "$T/ssh/sshd_config" <<EOF
HostKey $T/ssh/host_key
AuthorizedKeysFile $T/ssh/authorized_keys
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
StrictModes no
PidFile none
EOF

# cats1: accepts ssh.management on UDP loopback; ed209k is its peer
cat > "$T/a/services.txt" <<EOF
ssh.management management encrypt exec /usr/sbin/sshd -i -f $T/ssh/sshd_config
EOF
printf 'ed209k %s\n' "$A_PEER" > "$T/a/peers.txt"
cat > "$T/a/xtpd.conf" <<EOF
socket $T/a/xtpd.sock
services $T/a/services.txt
peers $T/a/peers.txt
keys $T/a/service.keys
routes $T/a/routes.tsv
listen $LISTEN
firewall_helper $REXX_BIN $ROOT/libexec/xtpd_firewall.rex
log $T/a/xtpd.log
EOF
# ed209k: no services of its own; cats1 is its peer
: > "$T/b/services.txt"
printf 'cats1 %s\n' "$B_PEER" > "$T/b/peers.txt"
cat > "$T/b/xtpd.conf" <<EOF
socket $T/b/xtpd.sock
services $T/b/services.txt
peers $T/b/peers.txt
keys $T/b/service.keys
routes $T/b/routes.tsv
log $T/b/xtpd.log
EOF

"$REXX_BIN" "$ROOT/bin/xtpd.rex" "$T/a/xtpd.conf" 2>"$T/a/stderr" & A_PID=$!
"$REXX_BIN" "$ROOT/bin/xtpd.rex" "$T/b/xtpd.conf" 2>"$T/b/stderr" & B_PID=$!
for _ in $(seq 1 100); do
  grep -q 'running:' "$T/a/xtpd.log" 2>/dev/null && grep -q 'running:' "$T/b/xtpd.log" 2>/dev/null && break
  sleep 0.1
done
grep -q 'running:' "$T/a/xtpd.log" || fail "cats1 xtpd did not start"
grep -q 'running:' "$T/b/xtpd.log" || fail "ed209k xtpd did not start"
pass "both daemons running"

if ss -ltnp 2>/dev/null | grep -q "rexx"; then fail "an xtpd process holds a TCP listener"; fi
pass "no TCP listener"

grep -q "flush" "$T/nft.calls" && grep -q "add element inet mu_fence xtp_peers { 127.0.0.1 }" "$T/nft.calls" \
  || fail "firewall helper was not asked to flush and add the peerage"
pass "start: fence set flushed, peerage added"

SSH=(ssh -F /dev/null -i "$T/ssh/client_key" -o IdentitiesOnly=yes -o BatchMode=yes
     -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$T/ssh/known_hosts"
     -o ProxyUseFdpass=yes
     -o "ProxyCommand=$REXX_BIN $ROOT/bin/xtp_request.rex --socket $T/b/xtpd.sock ssh.management cats1")
OUT=$(timeout 60 "${SSH[@]}" root@cats1 'echo hello over xtp' 2>"$T/ssh.err") || fail "ssh over xtp: $(cat "$T/ssh.err")"
[[ "$OUT" == "hello over xtp" ]] || fail "unexpected output: $OUT"
pass "ssh over xtp: a command ran on cats1"

SUM_DOWN=$(timeout 60 "${SSH[@]}" root@cats1 'head -c 300000 /dev/zero' 2>>"$T/ssh.err" | md5sum)
[[ "$SUM_DOWN" == "$(head -c 300000 /dev/zero | md5sum)" ]] || fail "download checksum differs"
pass "ssh over xtp: 300 kB download intact"

DATA=$(head -c 200000 /dev/urandom | base64 -w0)
SUM_IN=$(printf %s "$DATA" | md5sum)
SUM_OUT=$(printf %s "$DATA" | timeout 60 "${SSH[@]}" root@cats1 'md5sum' 2>>"$T/ssh.err") || fail "upload: $(cat "$T/ssh.err")"
[[ "$SUM_OUT" == "$SUM_IN" ]] || fail "upload checksum differs"
pass "ssh over xtp: 270 kB upload intact"

grep -q 'protection encrypt' "$T/a/xtpd.log" || fail "cats1 did not record an encrypted session"
pass "sessions were encrypted under the service key"

# cats1 writes a receipt when its end of the close completes, which can be a
# little after the client has returned: wait for it rather than race it.
for _ in $(seq 1 100); do
  N=$(grep -c 'receipt: ssh.management from ed209k' "$T/a/xtpd.log" || true)
  [[ "$N" -ge 3 ]] && break
  sleep 0.1
done
[[ "$N" -ge 3 ]] || fail "cats1 wrote $N receipts, expected 3"
pass "receipts written for each session on cats1"
BIG_SENT=$(grep -o "receipt: ssh.management from ed209k.* sent [0-9]*" "$T/a/xtpd.log" | awk "{print \$NF}" | sort -n | tail -1)
BIG_RECV=$(grep -o "received [0-9]*" "$T/a/xtpd.log" | awk "{print \$2}" | sort -n | tail -1)
[[ "$BIG_SENT" -ge 300000 && "$BIG_RECV" -ge 270000 ]] || fail "receipts do not show the transfers crossing XTP (sent $BIG_SENT, received $BIG_RECV)"
pass "receipts show the bytes crossed XTP: cats1 sent $BIG_SENT, received $BIG_RECV"

# an unknown service is refused by name, before any hook runs
if timeout 20 "$REXX_BIN" "$ROOT/bin/xtp_request.rex" --socket "$T/b/xtpd.sock" no.such.service cats1 </dev/null >/dev/null 2>"$T/req.err"; then fail "unknown service was not refused"; fi
pass "unknown service refused: $(head -c 120 "$T/req.err")"

# an unknown peer is refused locally
if timeout 20 "$REXX_BIN" "$ROOT/bin/xtp_request.rex" --socket "$T/b/xtpd.sock" ssh.management nowhere </dev/null >/dev/null 2>"$T/req2.err"; then fail "unknown peer was not refused"; fi
grep -q 'unknown peer' "$T/req2.err" || fail "unknown peer refusal text: $(cat "$T/req2.err")"
pass "unknown peer refused"

# a node holding a different secret under the same key id is refused
mkdir -p "$T/c"
WRONG=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
printf 'ssh.management\t00000000000055a1\tencrypt\tchacha20poly1305\t%s\n' "$WRONG" > "$T/c/service.keys"; chmod 600 "$T/c/service.keys"
: > "$T/c/services.txt"
printf 'cats1 %s\n' "$B_PEER" > "$T/c/peers.txt"
printf 'socket %s\nservices %s\npeers %s\nkeys %s\nroutes %s\nlog %s\n' "$T/c/xtpd.sock" "$T/c/services.txt" "$T/c/peers.txt" "$T/c/service.keys" "$T/c/routes.tsv" "$T/c/xtpd.log" > "$T/c/xtpd.conf"
"$REXX_BIN" "$ROOT/bin/xtpd.rex" "$T/c/xtpd.conf" 2>"$T/c/stderr" & C_PID=$!
for _ in $(seq 1 100); do grep -q 'running:' "$T/c/xtpd.log" 2>/dev/null && break; sleep 0.1; done
BEFORE=$(grep -c 'accepted:' "$T/a/xtpd.log")
if timeout 30 "$REXX_BIN" "$ROOT/bin/xtp_request.rex" --socket "$T/c/xtpd.sock" ssh.management cats1 </dev/null >/dev/null 2>"$T/req3.err"; then kill $C_PID; fail "a wrong key was accepted"; fi
kill -TERM $C_PID; wait $C_PID || true
AFTER=$(grep -c 'accepted:' "$T/a/xtpd.log")
[[ "$AFTER" == "$BEFORE" ]] || fail "cats1 accepted a session opened with the wrong secret"
pass "wrong secret refused before any hook: $(head -c 100 "$T/req3.err")"

# clean stop: socket removed, peerage withdrawn
kill -TERM "$A_PID"; wait "$A_PID" || true; A_PID=
[[ ! -e "$T/a/xtpd.sock" ]] || fail "request socket left behind"
grep -q "delete element inet mu_fence xtp_peers { 127.0.0.1 }" "$T/nft.calls" || fail "peerage not withdrawn at stop"
grep -q 'stopped' "$T/a/xtpd.log" || fail "no stop record"
pass "stop: socket removed, peerage withdrawn"
echo "PASS xtpd v0.1-dev1 local end-to-end"
