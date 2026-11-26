#!/usr/bin/env bash
# autobuild entry for MCP Project Service v0.2-dev9.  Claude (Opus 5.5).
# Builds the Foreign Runtime native library in a temporary copy (the repo copy
# carries no build output), then runs run_tests.sh against it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[[ -x "$REXX_BIN" ]] || { echo "FAIL rexx not found on PATH"; exit 2; }
for v in WIRE_UI_SERVER_HOME HTTPS_SERVER_HOME FOREIGN_RUNTIME_HOME QEB_HOME CRYPTO_HOME RUNTIME_REFERENCE_HOME; do
  [[ -n "${!v:-}" ]] || { echo "FAIL $v is not set"; exit 2; }
done
OOREXX_HOME="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
echo "building foreign runtime in $W"
cp -r "$FOREIGN_RUNTIME_HOME" "$W/fr"; rm -f "$W/fr"/build/*.so "$W/fr"/build/*.o
make -s -C "$W/fr" OOREXX="$OOREXX_HOME" build/libforeign_runtime.so >/dev/null
export OOREXX_HOME REXX_BIN FOREIGN_RUNTIME_HOME="$W/fr"
bash "$ROOT/run_tests.sh"
