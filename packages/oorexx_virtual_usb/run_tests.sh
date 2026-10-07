#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${REXX:=rexx}"

case "$REXX" in
  */*) REXX_EXE=$REXX ;;
  *) REXX_EXE=$(command -v "$REXX") ;;
esac
REXX_BIN=$(CDPATH= cd -- "$(dirname -- "$REXX_EXE")" && pwd)

prepend_rexx_path() {
  [ -d "$1" ] || return 0
  if [ -n "${REXX_PATH:-}" ]; then REXX_PATH="$1:$REXX_PATH"; else REXX_PATH=$1; fi
}
prepend_native_path() {
  [ -d "$1" ] || return 0
  if [ -n "${LD_LIBRARY_PATH:-}" ]; then LD_LIBRARY_PATH="$1:$LD_LIBRARY_PATH"; else LD_LIBRARY_PATH=$1; fi
}

# Package-owned paths are always reconstructed here.  External dependency roots
# may be supplied directly today; the package registry/SCCC resolver can supply
# the same roots without changing this test runner.
prepend_rexx_path "$REXX_BIN"
prepend_rexx_path "$ROOT/tests"
prepend_rexx_path "$ROOT/src"

if [ -n "${OOREXX_EVENT_RUNTIME_ROOT:-}" ]; then prepend_rexx_path "$OOREXX_EVENT_RUNTIME_ROOT/src"; fi
if [ -n "${OOREXX_CRYPTO_ROOT:-}" ]; then prepend_rexx_path "$OOREXX_CRYPTO_ROOT/src"; fi
if [ -n "${OOREXX_FOREIGN_RUNTIME_ROOT:-}" ]; then
  prepend_rexx_path "$OOREXX_FOREIGN_RUNTIME_ROOT/rexx"
  prepend_native_path "$OOREXX_FOREIGN_RUNTIME_ROOT/build"
fi

export REXX_PATH LD_LIBRARY_PATH
cd "$ROOT"

"$REXX_EXE" tests/test_dependency_environment.rex
"$REXX_EXE" tests/test_core.rex
"$REXX_EXE" tests/test_chapter9.rex
"$REXX_EXE" tests/test_profile.rex
"$REXX_EXE" tests/test_configuration_state.rex
"$REXX_EXE" tests/test_fido_hid_profile.rex
"$REXX_EXE" tests/test_fido_ctaphid.rex
"$REXX_EXE" tests/test_fido_getinfo.rex
"$REXX_EXE" tests/test_fido_credentials.rex
"$REXX_EXE" tests/test_raw_gadget_presentation_error.rex
"$REXX_EXE" tests/test_raw_gadget_control_direction.rex
"$REXX_EXE" tests/test_raw_gadget_bridge.rex
"$REXX_EXE" examples/virtual_crypto_profile.rex
"$REXX_EXE" examples/virtual_fido2_authenticator.rex

"$ROOT/tests/test_live_generation_guard.sh"
