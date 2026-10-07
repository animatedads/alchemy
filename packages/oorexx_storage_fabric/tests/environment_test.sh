#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"
export TERM="${TERM:-xterm}"

# Either point at an installed interpreter or supply the user-qualified .deb.
REXX_BIN=${REXX_BIN:-}
TMP_RUNTIME=""
if [[ -z "$REXX_BIN" ]]; then
  : "${OOREXX_DEB:?set REXX_BIN or OOREXX_DEB}"
  TMP_RUNTIME=$(mktemp -d "${TMPDIR:-/tmp}/storage-oorexx.XXXXXX")
  trap 'rm -rf "$TMP_RUNTIME"' EXIT
  dpkg-deb -x "$OOREXX_DEB" "$TMP_RUNTIME"
  REXX_BIN="$TMP_RUNTIME/usr/local/bin/rexx"
  export LD_LIBRARY_PATH="$TMP_RUNTIME/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export REXX_HOME="$TMP_RUNTIME/usr/local"
fi
: "${SOCKET_PROVIDER_SRC:?set SOCKET_PROVIDER_SRC to oorexx_socket_provider_v0.1-dev8/src}"

"$REXX_BIN" -v
export SOCKET_PROVIDER_SRC
REXX_BIN="$REXX_BIN" bash tests/run.sh

# Explicit integration repeat so its evidence is visually distinct.
export REXX_PATH="$HERE/src:$SOCKET_PROVIDER_SRC${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" tests/test_mesh_socket_port.rex
"$REXX_BIN" tests/test_mesh_authority.rex
"$REXX_BIN" tests/test_storage_intentions.rex
"$REXX_BIN" tests/test_failure_domain_replication.rex
REXX_BIN="$REXX_BIN" tests/test_git_provider.sh

echo "PASS STORAGE FABRIC v0.1-dev21 ENVIRONMENT QUALIFICATION"
