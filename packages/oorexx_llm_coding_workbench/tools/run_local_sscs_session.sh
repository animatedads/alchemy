#!/usr/bin/env bash
set -euo pipefail
: "${SSCS_ROOT:?SSCS_ROOT must point at the Semantic Source Store package root}"
: "${NOSQLSERVER_ROOT:?NOSQLSERVER_ROOT must point at the real NoSQLServer package root}"
: "${ALCHEMY_ROOT:?ALCHEMY_ROOT must point at the current compatible Alchemy Objects package root}"
: "${CRYPTO_ROOT:?CRYPTO_ROOT must point at the ooRexx Crypto package root}"
REXX=${REXX:-rexx}
HERE=$(cd "$(dirname "$0")" && pwd)
REXX_STDLIB=$(cd "$(dirname "$REXX")" && pwd)
for f in \
  "$SSCS_ROOT/src/SemanticSourceStore.cls" \
  "$SSCS_ROOT/src/SemanticSourceMcpDirect.cls" \
  "$SSCS_ROOT/src/SemanticSourceDevelopmentDesk.cls" \
  "$NOSQLSERVER_ROOT/src/NoSQLServer.cls" \
  "$ALCHEMY_ROOT/src/AlchemyObject.cls" \
  "$CRYPTO_ROOT/src/crypto.cls"
do
  test -f "$f" || { echo "missing dependency: $f" >&2; exit 70; }
done
export REXX_PATH="$NOSQLSERVER_ROOT/src:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$SSCS_ROOT/src:$REXX_STDLIB${REXX_PATH:+:$REXX_PATH}"
case ":$REXX_PATH:" in
  *":$SSCS_ROOT/test:"*) echo "refusing SSCS compile-stub test path at runtime" >&2; exit 71;;
esac
exec "$REXX" "$HERE/local_sscs_session.rex" "$@"
