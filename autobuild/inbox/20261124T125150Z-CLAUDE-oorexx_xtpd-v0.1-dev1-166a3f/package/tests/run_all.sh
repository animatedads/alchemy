#!/usr/bin/env bash
# run_all.sh -- build xtpd's dependencies in a temporary directory, then run
# the unit test and the end-to-end SSH test over UDP and over raw IP protocol 36.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026.
#
# Environment (directories of the source packages; nothing is built in them):
#   REXX_BIN                 ooRexx 5.3 interpreter (default: the rexx on PATH)
#   XTP_SRC                  oorexx_xtp v0.1-dev38 or later
#   PLANNER_SRC              oorexx_operational_degradation_planner v0.1-dev5
#   PROCESS_SRC              oorexx_process v0.1-dev2 or later
#   FOREIGN_RUNTIME_HOME     oorexx_foreign_runtime v0.22.6
#   UNIX_SOCKET_DIR          oorexx_unix_socket v0.6
#   LOGGING_DIR              oorexx_logging v0.7
# The end-to-end test needs root (sshd -i reads its host key); without root it
# reports SKIP and this runner says so in its last line.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"   # autobuild sets no REXX_BIN; use the rexx on PATH
export REXX_BIN
for v in REXX_BIN XTP_SRC PLANNER_SRC PROCESS_SRC FOREIGN_RUNTIME_HOME UNIX_SOCKET_DIR LOGGING_DIR; do
  [[ -n "${!v:-}" ]] || { echo "FAIL $v is not set"; exit 2; }
done
OOREXX_ROOT="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
echo "building dependencies in $W"
cp -r "$PLANNER_SRC" "$W/planner"; make -s -C "$W/planner" >/dev/null
cp -r "$XTP_SRC" "$W/xtp"; make -s -C "$W/xtp" OOREXX_INCLUDE="$OOREXX_ROOT/include" OPERATIONAL_PLANNER_DIR="$W/planner" lib/libxtp.a lib/liboorexx_xtp_native.so bin/xtp-admin >/dev/null
cp -r "$PROCESS_SRC" "$W/process"; make -s -C "$W/process/native" OOREXX_ROOT="$OOREXX_ROOT" >/dev/null
FR="$FOREIGN_RUNTIME_HOME"
if [[ ! -f "$FR/build/libforeign_runtime.so" ]]; then
  cp -r "$FR" "$W/fr"; make -s -C "$W/fr" OOREXX="$OOREXX_ROOT" build/libforeign_runtime.so >/dev/null; FR="$W/fr"
fi
export XTP_DIR="$W/xtp" PROCESS_DIR="$W/process" FOREIGN_RUNTIME_HOME="$FR"
export LD_LIBRARY_PATH="$W/xtp/lib:$FR/build:$W/process/native:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$W/xtp/rexx:$FR/rexx:$UNIX_SOCKET_DIR:$W/process/src:$W/process/src/providers:$LOGGING_DIR/src:$OOREXX_ROOT/bin"

"$REXX_BIN" "$ROOT/tests/test_units.rex"
skipped=0
for carrier in udp raw36; do
  set +e
  XTPD_TEST_CARRIER=$carrier bash "$ROOT/tests/test_local_ssh.sh"
  rc=$?
  set -e
  if [[ $rc -eq 77 ]]; then skipped=1; elif [[ $rc -ne 0 ]]; then echo "FAIL end-to-end over $carrier"; exit 1; fi
done
if [[ $skipped -eq 1 ]]; then echo "PASS xtpd units; end-to-end SKIPPED (needs root and OpenSSH)"; else echo "PASS xtpd units and end-to-end over udp and raw36"; fi
