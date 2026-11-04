#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX="${REXX:-rexx}"

need_dir(){ [[ -d "${!1:-}" ]] || { echo "NOT_RUN missing $1=${!1:-}" >&2; exit 2; }; }
for name in OOREXX_CRYPTO_ROOT SECRET_BROKER_ROOT ALCHEMY_OBJECTS_ROOT NOSQLSERVER_ROOT SOCKET_PROVIDER_ROOT; do need_dir "$name"; done
command -v "$REXX" >/dev/null 2>&1 || { echo "NOT_RUN ooRexx executable not found: $REXX" >&2; exit 2; }

export REXX_PATH="$ROOT:$OOREXX_CRYPTO_ROOT/src:$SECRET_BROKER_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$NOSQLSERVER_ROOT/src:$SOCKET_PROVIDER_ROOT/src${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"

echo "==> activation identity/ACL/revocation policy"
"$REXX" tests/test_activation_identity_policy.rex

echo "==> native LDAP listener + bind/search/authority"
bash tests/wire_smoke.sh

echo "==> NoSQL directory durability/restart"
"$REXX" tests/test_nosql_store.rex
"$REXX" tests/test_peer_failover_recovery.rex

echo "==> STARTTLS and LDAPS"
if [[ -n "${RUNTIME_REFERENCE_ROOT:-}" && -n "${FOREIGN_RUNTIME_ROOT:-}" && -f "$RUNTIME_REFERENCE_ROOT/src/RuntimeImplementationReference.cls" && -f "$FOREIGN_RUNTIME_ROOT/rexx/foreign.cls" ]]; then
  export REXX_PATH="$RUNTIME_REFERENCE_ROOT/src:$FOREIGN_RUNTIME_ROOT/rexx:$REXX_PATH"
  export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build:$OOREXX_CRYPTO_ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  bash tests/tls_wire_smoke.sh
  bash tests/ldaps_wire_smoke.sh
else
  echo "NOT_RUN STARTTLS/LDAPS: Runtime Reference / Foreign Runtime roots unavailable" >&2
  exit 2
fi

if [[ -n "${ACCESS_PERMISSIONS_ROOT:-}" && -n "${INSTITUTIONAL_POLICY_ROOT:-}" && -n "${SECURITY_EFFECT_ROOT:-}" ]]; then
  echo "==> Access Permissions adapter"
  bash tests/access_permissions_smoke.sh
else
  echo "NOT_RUN Access Permissions adapter: policy roots unavailable" >&2
  exit 2
fi

echo "PASS LDAP ACTIVATION REHEARSAL"
