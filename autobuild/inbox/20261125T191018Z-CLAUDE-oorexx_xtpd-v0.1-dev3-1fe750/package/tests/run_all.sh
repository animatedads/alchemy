#!/usr/bin/env bash
# run_all.sh -- build xtpd's dependencies in a temporary directory, then run
# the unit tests and the end-to-end SSH and role tests over UDP and over raw IP
# protocol 36.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 24 November 2026; dev2 25 November 2026.
#
# Environment (directories of the source packages; nothing is built in them):
#   REXX_BIN                 ooRexx 5.3 interpreter (default: the rexx on PATH)
#   XTP_SRC                  oorexx_xtp v0.1-dev38 or later
#   PLANNER_SRC              oorexx_operational_degradation_planner v0.1-dev5
#   PROCESS_SRC              oorexx_process v0.1-dev2 or later
#   FOREIGN_RUNTIME_HOME     oorexx_foreign_runtime v0.22.6
#   UNIX_SOCKET_DIR          oorexx_unix_socket v0.6
#   LOGGING_DIR              oorexx_logging v0.7
#   CRYPTO_DIR               oorexx_crypto v0.8.3                  (dev2)
#   BOOTSTRAP_DIR            xtpd_bootstrap v0.1-dev1 (ChatGPT)    (dev2)
#   ATOMIC_FILE_SRC          oorexx_atomic_file v0.1-dev1          (dev2)
#   LDAP_DIR                 oorexx_ldap_identity v0.1-dev9        (dev2, role test)
#   SECRET_BROKER_DIR        oorexx_secret_broker v0.2             (dev2, role test)
#   ALCHEMY_OBJECTS_DIR      alchemy_objects v0.8                  (dev2, role test)
# dev2: every native part is rebuilt from source here; binaries shipped inside a
# source package are never used (they may be built for another C library).
# The end-to-end test needs root (sshd -i reads its host key); without root it
# reports SKIP and this runner says so in its last line.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"   # autobuild sets no REXX_BIN; use the rexx on PATH
export REXX_BIN
for v in REXX_BIN XTP_SRC PLANNER_SRC PROCESS_SRC FOREIGN_RUNTIME_HOME UNIX_SOCKET_DIR LOGGING_DIR CRYPTO_DIR BOOTSTRAP_DIR ATOMIC_FILE_SRC; do
  [[ -n "${!v:-}" ]] || { echo "FAIL $v is not set"; exit 2; }
done
OOREXX_ROOT="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
echo "building dependencies in $W"
cp -r "$PLANNER_SRC" "$W/planner"; make -s -C "$W/planner" clean >/dev/null 2>&1 || true; make -s -C "$W/planner" >/dev/null
cp -r "$XTP_SRC" "$W/xtp"; make -s -C "$W/xtp" clean >/dev/null 2>&1 || true; make -s -C "$W/xtp" OOREXX_INCLUDE="$OOREXX_ROOT/include" OPERATIONAL_PLANNER_DIR="$W/planner" lib/libxtp.a lib/liboorexx_xtp_native.so bin/xtp-admin >/dev/null
cp -r "$PROCESS_SRC" "$W/process"; make -s -C "$W/process/native" clean >/dev/null 2>&1 || true; make -s -C "$W/process/native" OOREXX_ROOT="$OOREXX_ROOT" >/dev/null
cp -r "$FOREIGN_RUNTIME_HOME" "$W/fr"; rm -f "$W/fr"/build/*.so "$W/fr"/build/*.o
make -s -C "$W/fr" OOREXX="$OOREXX_ROOT" build/libforeign_runtime.so >/dev/null; FR="$W/fr"
cp -r "$ATOMIC_FILE_SRC" "$W/atomic"; rm -f "$W/atomic"/native/*.so
make -s -C "$W/atomic/native" OOREXX_ROOT="$OOREXX_ROOT" >/dev/null
export XTP_DIR="$W/xtp" PROCESS_DIR="$W/process" FOREIGN_RUNTIME_HOME="$FR" ATOMIC_FILE_DIR="$W/atomic"
export LD_LIBRARY_PATH="$W/xtp/lib:$FR/build:$W/process/native:$W/atomic/native:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$W/xtp/rexx:$FR/rexx:$UNIX_SOCKET_DIR:$W/process/src:$W/process/src/providers:$LOGGING_DIR/src:$CRYPTO_DIR/src:$BOOTSTRAP_DIR/src:$W/atomic/src:$W/atomic/src/providers:$OOREXX_ROOT/bin"

"$REXX_BIN" "$ROOT/tests/test_units.rex"
U="$W/units"; mkdir -p "$U"
( export REXX_PATH="$REXX_PATH${LDAP_DIR:+:$LDAP_DIR}"; "$REXX_BIN" "$ROOT/tests/test_roles_units.rex" "$U" "$REXX_BIN" "$ROOT" )
skipped=0
for carrier in udp raw36; do
  for t in test_local_ssh.sh test_local_roles.sh; do
    set +e
    XTPD_TEST_CARRIER=$carrier bash "$ROOT/tests/$t"
    rc=$?
    set -e
    if [[ $rc -eq 77 ]]; then skipped=1; elif [[ $rc -ne 0 ]]; then echo "FAIL $t over $carrier"; exit 1; fi
  done
done
if [[ $skipped -eq 1 ]]; then echo "PASS xtpd units; end-to-end SKIPPED in part (needs root, OpenSSH and the LDAP kits)"; else echo "PASS xtpd units, and SSH and roles end to end over udp and raw36"; fi
