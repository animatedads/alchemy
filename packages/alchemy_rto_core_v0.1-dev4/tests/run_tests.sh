#!/usr/bin/env bash
# alchemy_rto_core v0.1-dev4 tests. Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
# Two processes: send.rex captures, recv.rex (a new process) reconstructs and attacks.
# Runs in a temporary copy.  REXX_BIN (default rexx); CRYPTO_DIR (oorexx_crypto_v0.8.3).
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[ -x "$REXX_BIN" ] || { echo "FAIL no ooRexx interpreter (set REXX_BIN)"; exit 2; }
CRYPTO_DIR="${CRYPTO_DIR:-$SRC/../oorexx_crypto_v0.8.3}"
[ -f "$CRYPTO_DIR/src/crypto.cls" ] || { echo "FAIL oorexx_crypto_v0.8.3 not found (set CRYPTO_DIR)"; exit 2; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rto_core.XXXXXX")"
if [ "${KEEP:-0}" = "1" ]; then echo "KEEP: $WORK"; else trap 'rm -rf "$WORK"' EXIT; fi
cp -r "$SRC" "$WORK/pkg"; mkdir -p "$WORK/wire"
export REXX_PATH="$WORK/pkg/src:$CRYPTO_DIR/src${REXX_PATH:+:$REXX_PATH}"
echo "== interpreter: $("$REXX_BIN" -v 2>&1 | head -1)"
if grep -nE '^[[:space:]]*call[[:space:]]+\.?[A-Za-z_][A-Za-z0-9_.]*~' "$WORK"/pkg/src/*.cls "$WORK"/pkg/tests/*.rex; then echo "FAIL pitfall P7"; exit 3; fi
echo "== send (process 1)"
(cd "$WORK/pkg/tests" && "$REXX_BIN" send.rex "$WORK/wire")
echo "== receive (process 2)"
(cd "$WORK/pkg/tests" && "$REXX_BIN" recv.rex "$WORK/wire")
