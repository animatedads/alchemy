#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${OOREXX_DEB:?set OOREXX_DEB to the ooRexx 5.3.0 r13196 .deb}"
: "${OOREXX_CRYPTO_ROOT:?set OOREXX_CRYPTO_ROOT to ooRexx Crypto v0.8.3}"
: "${SECRET_BROKER_ROOT:?set SECRET_BROKER_ROOT to ooRexx Secret Broker v0.2}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT to Alchemy Objects v0.8}"
: "${NOSQLSERVER_ROOT:?set NOSQLSERVER_ROOT to NoSQLServer v0.85}"
: "${SOCKET_PROVIDER_ROOT:?set SOCKET_PROVIDER_ROOT to ooRexx Socket Provider v0.1-dev12}"
: "${INTENTION_SERVICE_ROOT:?set INTENTION_SERVICE_ROOT to ooRexx Intention Service v0.1-dev11}"

for f in \
  "$OOREXX_DEB" \
  "$OOREXX_CRYPTO_ROOT/src/crypto.cls" \
  "$SECRET_BROKER_ROOT/src/SecretBroker.cls" \
  "$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" \
  "$NOSQLSERVER_ROOT/src/NoSQLServer.cls" \
  "$SOCKET_PROVIDER_ROOT/src/SocketProvider.cls" \
  "$INTENTION_SERVICE_ROOT/src/IntentionService.cls"
do
  [[ -e "$f" ]] || { echo "missing environment dependency: $f" >&2; exit 2; }
done

work="$(mktemp -d "${TMPDIR:-/tmp}/ldap-dev14-env.XXXXXX")"
trap 'rm -rf "$work"' EXIT
runtime="$work/oorexx"
dpkg-deb -x "$OOREXX_DEB" "$runtime"

REXX_BIN="$runtime/usr/local/bin/rexx"
[[ -x "$REXX_BIN" ]] || { echo "ooRexx executable not found in supplied .deb" >&2; exit 2; }

export PATH="$runtime/usr/local/bin:$PATH"
export LD_LIBRARY_PATH="$runtime/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX="$REXX_BIN"

version="$($REXX_BIN -v 2>&1 | head -n 2 | tr '\n' ' ')"
echo "ooRexx runtime: $version"
if ! "$REXX_BIN" -v 2>&1 | grep -q '13196'; then
  echo "expected ooRexx r13196 for the reference qualification" >&2
  exit 2
fi

# Optional accelerated TLS/crypto paths are enabled automatically by run_tests.sh
# when both package roots are supplied.
export RUNTIME_REFERENCE_ROOT="${RUNTIME_REFERENCE_ROOT:-}"
export FOREIGN_RUNTIME_ROOT="${FOREIGN_RUNTIME_ROOT:-}"

cd "$ROOT"
echo "==> full LDAP/Identity suite"
bash ./run_tests.sh

if [[ "${LDAP_RUN_ACCESS_PERMISSIONS:-0}" == "1" ]]; then
  : "${ACCESS_PERMISSIONS_ROOT:?LDAP_RUN_ACCESS_PERMISSIONS=1 requires ACCESS_PERMISSIONS_ROOT}"
  : "${INSTITUTIONAL_POLICY_ROOT:?LDAP_RUN_ACCESS_PERMISSIONS=1 requires INSTITUTIONAL_POLICY_ROOT}"
  : "${SECURITY_EFFECT_ROOT:?LDAP_RUN_ACCESS_PERMISSIONS=1 requires SECURITY_EFFECT_ROOT}"
  echo "==> Access Permissions integration"
  bash ./tests/access_permissions_smoke.sh
fi

echo "LDAP DEV14 ENVIRONMENT: OK"
