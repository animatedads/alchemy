#!/bin/bash
set -euo pipefail

# Complete target-host bring-up and live qualification for the development
# FIDO2 authenticator. Host preparation is delegated to
# prepare_raw_gadget_host.sh, which validates/rebuilds dummy_hcd for the running
# kernel and installs that module into the matching /lib/modules tree.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${REXX:=rexx}"
: "${OOREXX_VUSB_UDC_DRIVER:=dummy_udc}"
: "${OOREXX_VUSB_UDC_DEVICE:=dummy_udc.0}"
: "${OOREXX_VUSB_RAW_GADGET_PATH:=/dev/raw-gadget}"
: "${OOREXX_VUSB_DUMMY_HCD_SOURCE_DIR:=$(CDPATH= cd -- "$ROOT/.." && pwd)/dummy-hcd}"
: "${OOREXX_VUSB_DUMMY_HCD_MODULE:=$OOREXX_VUSB_DUMMY_HCD_SOURCE_DIR/dummy_hcd.ko}"

fail() { echo "RAW FIDO2 HOST: FAIL: $*" >&2; exit 1; }
note() { echo "RAW FIDO2 HOST: $*"; }

INSTALL_BUILD_DEPS=0
INTERNAL_ROOT_HANDOFF=0
EVENT_ROOT=${OOREXX_EVENT_RUNTIME_ROOT:-}
CRYPTO_ROOT=${OOREXX_CRYPTO_ROOT:-}
FOREIGN_ROOT=${OOREXX_FOREIGN_RUNTIME_ROOT:-}

# Parse the private sudo handoff before the public CLI. dev6 rejected its own
# generated --as-root marker because public argument parsing ran first.
if [ "${1:-}" = "--as-root" ]; then
  INTERNAL_ROOT_HANDOFF=1
  [ "$#" -eq 11 ] || fail "internal root handoff argument mismatch"
  shift
  REXX_EXE=$1; EVENT_ROOT=$2; CRYPTO_ROOT=$3; FOREIGN_ROOT=$4
  OOREXX_VUSB_DUMMY_HCD_SOURCE_DIR=$5; OOREXX_VUSB_DUMMY_HCD_MODULE=$6
  OOREXX_VUSB_UDC_DRIVER=$7; OOREXX_VUSB_UDC_DEVICE=$8; OOREXX_VUSB_RAW_GADGET_PATH=$9
  INSTALL_BUILD_DEPS=${10}
  shift 10
else
  case "${1:-}" in
    "") ;;
    --install-build-deps) INSTALL_BUILD_DEPS=1; shift ;;
    *) echo "RAW FIDO2 HOST: FAIL: unknown argument: $1" >&2; exit 2 ;;
  esac
  [ "$#" -eq 0 ] || { echo "RAW FIDO2 HOST: FAIL: unexpected extra argument: $1" >&2; exit 2; }

  case "$REXX" in
    /*) REXX_EXE=$REXX ;;
    */*) REXX_EXE=$(CDPATH= cd -- "$(dirname -- "$REXX")" && pwd)/$(basename -- "$REXX") ;;
    *) REXX_EXE=$(command -v "$REXX" || true) ;;
  esac
  [ -n "${REXX_EXE:-}" ] && [ -x "$REXX_EXE" ] || fail "ooRexx executable not found"
fi

# Resolve interpreter/dependencies while still in the caller environment, then
# pass absolute values across sudo. The live presenter remains root because
# /dev/raw-gadget is normally root-owned mode 0600.
if [ "$(id -u)" -ne 0 ]; then
  note "re-executing as root for running-kernel module preparation and Raw Gadget access"
  exec sudo -- "$0" --as-root "$REXX_EXE" "$EVENT_ROOT" "$CRYPTO_ROOT" "$FOREIGN_ROOT" \
      "$OOREXX_VUSB_DUMMY_HCD_SOURCE_DIR" "$OOREXX_VUSB_DUMMY_HCD_MODULE" \
      "$OOREXX_VUSB_UDC_DRIVER" "$OOREXX_VUSB_UDC_DEVICE" "$OOREXX_VUSB_RAW_GADGET_PATH" "$INSTALL_BUILD_DEPS"
fi

[ "$INTERNAL_ROOT_HANDOFF" -eq 0 ] || note "root handoff accepted"

export REXX="$REXX_EXE"
[ -n "$EVENT_ROOT" ] && export OOREXX_EVENT_RUNTIME_ROOT="$EVENT_ROOT"
[ -n "$CRYPTO_ROOT" ] && export OOREXX_CRYPTO_ROOT="$CRYPTO_ROOT"
[ -n "$FOREIGN_ROOT" ] && export OOREXX_FOREIGN_RUNTIME_ROOT="$FOREIGN_ROOT"
export OOREXX_VUSB_DUMMY_HCD_SOURCE_DIR OOREXX_VUSB_DUMMY_HCD_MODULE
export OOREXX_VUSB_UDC_DRIVER OOREXX_VUSB_UDC_DEVICE OOREXX_VUSB_RAW_GADGET_PATH

version=$($REXX_EXE -v 2>&1 | head -1 || true)
case "$version" in
  *"5.3.0 r13196"*) note "ooRexx baseline OK: $version" ;;
  *) fail "expected ooRexx 5.3.0 r13196; got: $version" ;;
esac

prep_args=()
[ "$INSTALL_BUILD_DEPS" -eq 1 ] && prep_args+=(--install-build-deps)
"$ROOT/tests/prepare_raw_gadget_host.sh" "${prep_args[@]}"

if "$ROOT/tests/live_raw_gadget_fido.sh"; then
  note "PASS complete Raw Gadget FIDO2 host qualification"
  exit 0
else
  rc=$?
  note "live qualification failed rc=$rc; recent kernel USB diagnostics follow"
  dmesg 2>/dev/null | tail -n 100 >&2 || true
  exit "$rc"
fi
