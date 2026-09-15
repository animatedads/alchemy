#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /mnt/data/qrx-peer-socket.XXXXXX)"
trap 'jobs -pr | xargs -r kill -9 2>/dev/null || true; rm -rf "$TMP"' EXIT
KEY="$(printf '33%.0s' {1..64})"
AP="$TMP/a.port"; BP="$TMP/b.port"; AR="$TMP/a.result"; BR="$TMP/b.result"
REXX="${REXX:-rexx}"
"$REXX" "$ROOT/tests/peer_mesh_socket_client.rex" "$TMP/a" "$AP" "$BP" "$AR" "$KEY" >"$TMP/a.out" 2>"$TMP/a.err" & APID=$!
for _ in $(seq 1 300); do [[ -s "$AP" ]] && break; kill -0 "$APID" 2>/dev/null || { cat "$TMP/a.out" "$TMP/a.err" >&2; exit 1; }; sleep .025; done
[[ -s "$AP" ]] || { echo no-a-port >&2; exit 1; }
APORT="$(tr -d '\r\n' < "$AP")"
"$REXX" "$ROOT/tests/peer_mesh_socket_server.rex" "$TMP/b" "$APORT" "$BP" "$BR" "$KEY" >"$TMP/b.out" 2>"$TMP/b.err" & BPID=$!
wait "$APID" || { cat "$TMP/a.out" "$TMP/a.err" >&2; cat "$TMP/b.out" "$TMP/b.err" >&2; exit 1; }
wait "$BPID" || { cat "$TMP/b.out" "$TMP/b.err" >&2; exit 1; }
A="$(cat "$AR")"; B="$(cat "$BR")"
[[ "$A" == *"decision=APPROVE;source=B"* ]]
[[ "$A" == *"auth=1;accepted=1"* ]]
[[ "$B" == *"auth=1;accepted=1"* ]]
echo "PASS QueueRexx dev12 peer mesh encrypted queue.transport/2: authenticated QueueRexx A -> QueueRexx B approval request/reply with bound peer identity"
