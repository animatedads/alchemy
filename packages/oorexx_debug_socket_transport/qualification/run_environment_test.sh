#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REXX=${REXX:-rexx}

printf '%s\n' '== Debug Socket Transport environment qualification =='
printf 'root=%s\n' "$ROOT"
printf 'rexx=%s\n' "$REXX"

"$ROOT/validate_package.sh"

if ! command -v "$REXX" >/dev/null 2>&1; then
  echo "FAIL: ooRexx executable not found: $REXX" >&2
  exit 1
fi

"$REXX" -v 2>&1 | head -n 2 || true
"$ROOT/run_tests.sh"

# Optional estate integration hook. The test itself remains in the estate Socket
# provider package because SocketSelector acquisition is provider-owned. Point this
# at that package's real environment qualification to prove both components together.
if [ -n "${SOCKET_PROVIDER_ENV_TEST:-}" ]; then
  if [ ! -x "$SOCKET_PROVIDER_ENV_TEST" ]; then
    echo "FAIL: SOCKET_PROVIDER_ENV_TEST is not executable: $SOCKET_PROVIDER_ENV_TEST" >&2
    exit 1
  fi
  echo "== estate SocketProvider qualification =="
  "$SOCKET_PROVIDER_ENV_TEST"
fi

echo 'ENVIRONMENT QUALIFICATION: OK'
