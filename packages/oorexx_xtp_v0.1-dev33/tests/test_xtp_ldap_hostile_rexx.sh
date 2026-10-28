#!/usr/bin/env bash
# dev33: hostile Identity Directory entries cannot plant keys or block refreshes.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
# Needs the same roots as tests/test_xtp_service_keys_rexx.sh.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" || ! -x "${REXX_BIN}" ]]; then echo 'SKIP hostile LDAP entries (REXX_BIN unavailable)'; exit 0; fi
for v in LDAP_IDENTITY_ROOT SOCKET_PROVIDER_DIR CRYPTO_ROOT SECRET_BROKER_ROOT ALCHEMY_OBJECTS_ROOT; do
  if [[ -z "${!v:-}" ]]; then echo "SKIP hostile LDAP entries ($v not set)"; exit 0; fi
done
TMP="$(mktemp -d)"; PIDS=(); trap 'kill ${PIDS[@]:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
export REXX_PATH="$ROOT/rexx:$LDAP_IDENTITY_ROOT:$SOCKET_PROVIDER_DIR:$CRYPTO_ROOT:$SECRET_BROKER_ROOT:$ALCHEMY_OBJECTS_ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
SECRET="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
rc=0; i=0
for mode in tenant inject placement; do
  port=$((57000 + RANDOM % 300 + i * 300)); i=$((i+1))
  "$REXX_BIN" "$ROOT/tests/xtp_keys_ldap_hostile_fixture.rex" $port "$TMP/$mode.ready" 1 "$SECRET" $mode >"$TMP/$mode.out" 2>&1 & PIDS+=($!)
  for _ in $(seq 1 1200); do [[ -f "$TMP/$mode.ready" ]] && break; sleep .05; done
  [[ -f "$TMP/$mode.ready" ]] || { echo "FAIL $mode: fixture did not start"; tail "$TMP/$mode.out"; rc=1; continue; }
  "$REXX_BIN" "$ROOT/tests/test_xtp_ldap_hostile_client.rex" $port "$SECRET" $mode || rc=1
  grep FIXTURE "$TMP/$mode.out" || true
done
if [[ $rc -ne 0 ]]; then echo 'FAIL hostile LDAP entries'; exit 1; fi
echo 'PASS hostile LDAP entries: no key planted through a crafted name or a misplaced generation; a broken tenant set does not block a revocation and rotation'
