#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
REXXC_BIN="${REXXC_BIN:-rexxc}"
command -v "$REXX_BIN" >/dev/null 2>&1 || { echo "rexx not found: $REXX_BIN" >&2; exit 2; }
command -v "$REXXC_BIN" >/dev/null 2>&1 || { echo "rexxc not found: $REXXC_BIN" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum not found" >&2; exit 2; }
[[ -n "${REXX_PATH:-}" ]] || { echo "REXX_PATH must include QueueRexx, Queue Fabric, Crypto, POSIX and their dependencies" >&2; exit 2; }
export REXX_PATH="$ROOT:$ROOT/src:${REXX_PATH}"
"$REXXC_BIN" "$ROOT/bin/storage-peer-queuerexx-server.rex" >/dev/null
"$REXXC_BIN" "$ROOT/bin/storage-peer-queuerexx-client.rex" >/dev/null
TMP="$(mktemp "${TMPDIR:-/tmp}/storage-peer-preflight.XXXXXX.rex")"
trap 'rm -f "$TMP"' EXIT
cat >"$TMP" <<'REXX'
r=.QueueDigestProvider~new~digestWithEvidence("storage-peer-preflight")
if r~digest="" then exit 3
say "QUEUE_DIGEST provider="r~providerId "accelerated="r~accelerated "outcome="r~outcomeCode
say "PASS Storage peer QueueRexx dependency preflight"
exit 0
::requires "StoragePeer.cls"
::requires "QueueRexxPeerMesh.cls"
REXX
"$REXX_BIN" "$TMP"
