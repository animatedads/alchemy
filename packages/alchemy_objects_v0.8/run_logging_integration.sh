#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOGGING_INPUT=${1:-}
CRYPTO_INPUT=${2:-${OOREXX_CRYPTO_SRC:-}}

usage() {
  echo "usage: $0 /path/to/oorexx_logging_v0.3 /path/to/oorexx_crypto_v0.1/src" >&2
  exit 2
}
[ -n "$LOGGING_INPUT" ] && [ -n "$CRYPTO_INPUT" ] || usage
if [ -d "$LOGGING_INPUT/src" ]; then LOGGING_ROOT=$(CDPATH= cd -- "$LOGGING_INPUT" && pwd)
elif [ -f "$LOGGING_INPUT/LoggingCore.cls" ]; then LOGGING_ROOT=$(CDPATH= cd -- "$(dirname -- "$LOGGING_INPUT")/.." && pwd)
else usage
fi
if [ -f "$CRYPTO_INPUT" ]; then CRYPTO_SRC=$(CDPATH= cd -- "$(dirname -- "$CRYPTO_INPUT")" && pwd)
elif [ -d "$CRYPTO_INPUT" ]; then CRYPTO_SRC=$(CDPATH= cd -- "$CRYPTO_INPUT" && pwd)
else usage
fi
[ -f "$LOGGING_ROOT/src/LoggingCore.cls" ] || usage
[ -f "$CRYPTO_SRC/crypto.cls" ] || usage
REXX_INPUT=${OOREXX_REXX:-${REXX:-rexx}}
case "$REXX_INPUT" in *[[:space:]]*) echo "error: interpreter override must name one executable" >&2; exit 2;; esac
if [ -x "$REXX_INPUT" ] && [ "${REXX_INPUT#/}" != "$REXX_INPUT" ]; then REXX_BIN="$REXX_INPUT"
elif command -v "$REXX_INPUT" >/dev/null 2>&1; then REXX_BIN=$(command -v "$REXX_INPUT")
else echo "error: ooRexx interpreter not found: $REXX_INPUT" >&2; exit 2
fi
export REXX_PATH="$ROOT/src:$ROOT/inspector:$CRYPTO_SRC:$LOGGING_ROOT/src${REXX_PATH:+:$REXX_PATH}"
run() { echo ">>> $*"; "$@"; }
# Existing Logging package regression: Alchemy wrapper first, Logging second.
cd "$LOGGING_ROOT/tests"
run "$REXX_BIN" test_alchemy_preexisting_telemetry.rex
# Alchemy-owned reverse-order and unsafe-release cases.
cd "$ROOT/integration"
run "$REXX_BIN" test_logging_first_alchemy.rex
run "$REXX_BIN" test_alchemy_first_remove_while_logging.rex
