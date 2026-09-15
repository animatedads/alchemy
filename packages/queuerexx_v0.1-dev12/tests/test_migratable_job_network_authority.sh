#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /mnt/data/qrx-mj-network1-socket.XXXXXX)"
trap 'jobs -pr | xargs -r kill -9 2>/dev/null || true; rm -rf "$TMP"' EXIT
: "${QF_CRYPTO_FOREIGN_BRIDGE:?QF_CRYPTO_FOREIGN_BRIDGE required}"
REXX="${REXX:-rexx}"
KEY="$(printf '55%.0s' {1..64})"
AP="$TMP/a.port"; BP="$TMP/b.port"; AR="$TMP/a.result"; BR="$TMP/b.result"
"$REXX" "$ROOT/tests/migratable_network_socket_client.rex" "$TMP/a" "$AP" "$BP" "$AR" "$KEY" >"$TMP/a.out" 2>"$TMP/a.err" & APID=$!
for _ in $(seq 1 400); do [[ -s "$AP" ]] && break; kill -0 "$APID" 2>/dev/null || { cat "$TMP/a.out" "$TMP/a.err" >&2; exit 1; }; sleep .025; done
[[ -s "$AP" ]] || { echo no-client-port >&2; exit 1; }
APORT="$(tr -d '\r\n' < "$AP")"
"$REXX" "$ROOT/tests/migratable_network_socket_server.rex" "$TMP/b" "$APORT" "$BP" "$BR" "$KEY" >"$TMP/b.out" 2>"$TMP/b.err" & BPID=$!
set +e
wait "$APID"; ARC=$?
wait "$BPID"; BRC=$?
set -e
if (( ARC != 0 || BRC != 0 )); then cat "$TMP/a.out" "$TMP/a.err" "$TMP/b.out" "$TMP/b.err" >&2; exit 1; fi
A="$(cat "$AR")"; B="$(cat "$BR")"
[[ "$A" == *"node=FD-AUTH-NODE"* ]]
[[ "$A" == *"starts=1;replayed=1"* ]]
[[ "$A" == *"auth=10;accepted=10"* ]]
[[ "$B" == *"auth=10;accepted=10"* ]]
echo "PASS QueueRexx dev12 full remote Migratable Job v0.2.4 stack: peer mesh + exact network1 PLAN/ALLOCATE/CHECK/RENEW/RELEASE + dual lease verification + migratable.job.start/1 + replay-safe private worker"
