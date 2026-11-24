#!/usr/bin/env bash
# run_dev2.sh -- build the dev2 provider and run dev1's tests plus test_dev2.rex.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026.
# Environment: REXX_BIN (ooRexx 5.3), FOREIGN_RUNTIME_HOME and UNIX_SOCKET_DIR
# (test_dev2 uses a real socketpair).  Foreign Runtime is built in a temporary
# copy when its build/ has no library, so the source tree is never written.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
[[ -x "$REXX_BIN" ]] || { echo "FAIL no ooRexx interpreter (set REXX_BIN or put rexx on PATH)"; exit 2; }
OOREXX_ROOT="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp -r "$ROOT" "$WORK/process"
make -s -C "$WORK/process/native" OOREXX_ROOT="$OOREXX_ROOT"
FR="${FOREIGN_RUNTIME_HOME:?FOREIGN_RUNTIME_HOME must name oorexx_foreign_runtime v0.22.6}"
if [[ ! -f "$FR/build/libforeign_runtime.so" ]]; then
  cp -r "$FR" "$WORK/fr"; make -s -C "$WORK/fr" OOREXX="$OOREXX_ROOT" build/libforeign_runtime.so; FR="$WORK/fr"
fi
export LD_LIBRARY_PATH="$FR/build:$OOREXX_ROOT/lib:$WORK/process/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$WORK/process/src:$WORK/process/src/providers:$FR/rexx:${UNIX_SOCKET_DIR:?UNIX_SOCKET_DIR must name oorexx_unix_socket v0.6}:$OOREXX_ROOT/bin"
"$REXX_BIN" "$WORK/process/tests/test_smoke.rex"
"$REXX_BIN" "$WORK/process/tests/test_contract.rex"
"$REXX_BIN" "$WORK/process/tests/test_dev2.rex"
