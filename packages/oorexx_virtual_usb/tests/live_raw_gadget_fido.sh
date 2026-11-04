#!/bin/bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${REXX:=rexx}"
: "${OOREXX_VUSB_UDC_DRIVER:=dummy_udc}"
: "${OOREXX_VUSB_UDC_DEVICE:=dummy_udc.0}"
: "${OOREXX_VUSB_SPEED:=HIGH}"
: "${OOREXX_VUSB_RAW_GADGET_PATH:=/dev/raw-gadget}"
: "${VUSB_LIVE_TIMEOUT:=20}"
: "${VUSB_SYSFS_ROOT:=/sys}"
: "${VUSB_DEV_ROOT:=/dev}"

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
export OOREXX_VUSB_UDC_DRIVER OOREXX_VUSB_UDC_DEVICE OOREXX_VUSB_SPEED OOREXX_VUSB_RAW_GADGET_PATH
: "${OOREXX_VUSB_TRACE:=1}"
export OOREXX_VUSB_TRACE

fail() { echo "LIVE RAW FIDO2: FAIL: $*" >&2; exit 1; }
note() { echo "LIVE RAW FIDO2: $*"; }

version=$($REXX_EXE -v 2>&1 | head -1 || true)
case "$version" in
  *"5.3.0 r13196"*) note "ooRexx baseline OK: $version" ;;
  *) fail "expected ooRexx 5.3.0 r13196; got: $version" ;;
esac

cd "$ROOT"
"$REXX_EXE" tests/test_dependency_environment.rex >/dev/null
note "dependency closure load OK"

[ -c "$OOREXX_VUSB_RAW_GADGET_PATH" ] || fail "$OOREXX_VUSB_RAW_GADGET_PATH is not a character device"
[ -r "$OOREXX_VUSB_RAW_GADGET_PATH" ] && [ -w "$OOREXX_VUSB_RAW_GADGET_PATH" ] || fail "$OOREXX_VUSB_RAW_GADGET_PATH is not readable/writable by this process"
[ -e "$VUSB_SYSFS_ROOT/class/udc/$OOREXX_VUSB_UDC_DEVICE" ] || fail "UDC $OOREXX_VUSB_UDC_DEVICE is not present under $VUSB_SYSFS_ROOT/class/udc"

if [ -r "$VUSB_SYSFS_ROOT/class/udc/$OOREXX_VUSB_UDC_DEVICE/uevent" ]; then
  actual_driver=$(sed -n 's/^USB_UDC_NAME=//p' "$VUSB_SYSFS_ROOT/class/udc/$OOREXX_VUSB_UDC_DEVICE/uevent" | head -1)
  if [ -n "$actual_driver" ] && [ "$actual_driver" != "$OOREXX_VUSB_UDC_DRIVER" ]; then
    fail "UDC driver mismatch: requested $OOREXX_VUSB_UDC_DRIVER, kernel reports $actual_driver"
  fi
fi
note "raw-gadget substrate OK: driver=$OOREXX_VUSB_UDC_DRIVER device=$OOREXX_VUSB_UDC_DEVICE"

report_raw_gadget_holders() {
  if command -v fuser >/dev/null 2>&1; then
    fuser -v "$OOREXX_VUSB_RAW_GADGET_PATH" 2>&1 || true
    return
  fi
  local proc fd target cmd
  for proc in /proc/[0-9]*; do
    [ -d "$proc/fd" ] || continue
    for fd in "$proc"/fd/*; do
      [ -e "$fd" ] || continue
      target=$(readlink -f "$fd" 2>/dev/null || true)
      [ "$target" = "$OOREXX_VUSB_RAW_GADGET_PATH" ] || continue
      cmd=$(tr '\0' ' ' <"$proc/cmdline" 2>/dev/null || true)
      printf '  pid=%s cmd=%s\n' "${proc##*/}" "$cmd" >&2
      break
    done
  done
}

UDC_STATE_FILE="$VUSB_SYSFS_ROOT/class/udc/$OOREXX_VUSB_UDC_DEVICE/state"
if [ -r "$UDC_STATE_FILE" ]; then
  UDC_STATE=$(cat "$UDC_STATE_FILE")
  case "$UDC_STATE" in
    "not attached"|"") ;;
    *)
      note "UDC is already active before this presenter: state=$UDC_STATE"
      note "processes currently holding $OOREXX_VUSB_RAW_GADGET_PATH"
      report_raw_gadget_holders
      fail "refusing to qualify against a pre-existing Raw Gadget generation"
      ;;
  esac
fi

snapshot_matching_usb() {
  local d v p devnum
  for d in "$VUSB_SYSFS_ROOT"/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue
    [ -f "$d/idProduct" ] || continue
    v=$(tr '[:upper:]' '[:lower:]' <"$d/idVendor")
    p=$(tr '[:upper:]' '[:lower:]' <"$d/idProduct")
    [ "$v" = "cafe" ] && [ "$p" = "f1d0" ] || continue
    devnum=$(cat "$d/devnum" 2>/dev/null || printf '?')
    printf '%s:%s\n' "$(basename "$d")" "$devnum"
  done
}

BASELINE=$(mktemp /tmp/oorexx-vusb-fido-baseline.XXXXXX)
snapshot_matching_usb >"$BASELINE"
if [ -s "$BASELINE" ]; then
  note "pre-existing CAFE:F1D0 generations will not count as this run:"
  sed 's/^/  /' "$BASELINE"
fi

# hidraw class objects have their own lifetime.  A stale class entry can survive
# long enough for a reused USB path to make its device symlink resolve again.
# Snapshot the class-object identity itself (not just its target path) so only a
# newly published/rebound hidraw generation can satisfy this run.
hidraw_class_token() {
  local h=$1 meta
  meta=$(stat -c '%d:%i:%y' "$h" 2>/dev/null || true)
  [ -n "$meta" ] || return 1
  printf '%s|%s\n' "$(basename "$h")" "$meta"
}

snapshot_hidraw_classes() {
  local h token
  for h in "$VUSB_SYSFS_ROOT"/class/hidraw/hidraw*; do
    [ -e "$h" ] || [ -L "$h" ] || continue
    token=$(hidraw_class_token "$h" || true)
    [ -n "$token" ] && printf '%s\n' "$token"
  done
}

HIDRAW_BASELINE=$(mktemp /tmp/oorexx-vusb-hidraw-baseline.XXXXXX)
snapshot_hidraw_classes >"$HIDRAW_BASELINE"
if [ -s "$HIDRAW_BASELINE" ]; then
  note "pre-existing hidraw class generations will not count as this run:"
  sed 's/^/  /' "$HIDRAW_BASELINE"
fi

LOG=$(mktemp /tmp/oorexx-vusb-fido-live.XXXXXX.log)
RUN_DIR=$(mktemp -d /tmp/oorexx-vusb-fido-run.XXXXXX)
READY="$RUN_DIR/presented"
TRACE="$RUN_DIR/raw-gadget.trace"
PRESENTER_PID=''
cleanup() {
  set +e
  if [ -n "$PRESENTER_PID" ] && kill -0 "$PRESENTER_PID" 2>/dev/null; then
    kill -INT "$PRESENTER_PID" 2>/dev/null
    for _ in 1 2 3 4 5; do
      kill -0 "$PRESENTER_PID" 2>/dev/null || break
      sleep 0.2
    done
  fi
  if [ -n "$PRESENTER_PID" ] && kill -0 "$PRESENTER_PID" 2>/dev/null; then
    kill -TERM "$PRESENTER_PID" 2>/dev/null
    for _ in 1 2 3 4 5; do
      kill -0 "$PRESENTER_PID" 2>/dev/null || break
      sleep 0.2
    done
  fi
  if [ -n "$PRESENTER_PID" ] && kill -0 "$PRESENTER_PID" 2>/dev/null; then
    kill -KILL "$PRESENTER_PID" 2>/dev/null
  fi
  [ -z "$PRESENTER_PID" ] || wait "$PRESENTER_PID" 2>/dev/null
  rm -f "$BASELINE" "$HIDRAW_BASELINE"
  rm -rf "$RUN_DIR"
}
trap cleanup EXIT INT TERM

OOREXX_VUSB_READY_FILE="$READY" OOREXX_VUSB_TRACE_FILE="$TRACE" \
  "$REXX_EXE" examples/virtual_fido2_authenticator_raw.rex >"$LOG" 2>&1 &
PRESENTER_PID=$!
note "presenter pid=$PRESENTER_PID log=$LOG trace=$TRACE"

# The presenter must prove that its own USB_RAW_IOCTL_RUN succeeded before any
# sysfs device is considered.  This prevents a stale CAFE:F1D0 from an older
# presenter from being mistaken for the current run.
PRESENTED=0
for ((i=0; i<VUSB_LIVE_TIMEOUT*10; i++)); do
  if [ -s "$READY" ]; then PRESENTED=1; break; fi
  if ! kill -0 "$PRESENTER_PID" 2>/dev/null; then
    cat "$LOG" >&2 || true
    [ ! -s "$TRACE" ] || cat "$TRACE" >&2
    fail "presenter exited before acquiring the requested UDC"
  fi
  sleep 0.1
done
[ "$PRESENTED" -eq 1 ] || {
  cat "$LOG" >&2 || true
  [ ! -s "$TRACE" ] || cat "$TRACE" >&2
  fail "presenter did not confirm UDC ownership within ${VUSB_LIVE_TIMEOUT}s"
}
note "presenter ownership OK: $(cat "$READY")"

find_usb_device() {
  local d v p devnum token
  for d in "$VUSB_SYSFS_ROOT"/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue
    [ -f "$d/idProduct" ] || continue
    v=$(tr '[:upper:]' '[:lower:]' <"$d/idVendor")
    p=$(tr '[:upper:]' '[:lower:]' <"$d/idProduct")
    if [ "$v" = "cafe" ] && [ "$p" = "f1d0" ]; then
      devnum=$(cat "$d/devnum" 2>/dev/null || printf '?')
      token="$(basename "$d"):$devnum"
      if ! grep -Fqx "$token" "$BASELINE"; then
        printf '%s\n' "$d"
        return 0
      fi
    fi
  done
  return 1
}

USB_PATH=''
for ((i=0; i<VUSB_LIVE_TIMEOUT*10; i++)); do
  if ! kill -0 "$PRESENTER_PID" 2>/dev/null; then
    cat "$LOG" >&2 || true
    [ ! -s "$TRACE" ] || cat "$TRACE" >&2
    fail "presenter exited before a new USB generation enumerated"
  fi
  if USB_PATH=$(find_usb_device); then break; fi
  sleep 0.1
done

[ -n "$USB_PATH" ] || {
  cat "$LOG" >&2 || true
  [ ! -s "$TRACE" ] || cat "$TRACE" >&2
  fail "a new CAFE:F1D0 generation did not enumerate within ${VUSB_LIVE_TIMEOUT}s"
}
USB_DEVNUM=$(cat "$USB_PATH/devnum" 2>/dev/null || printf '?')
USB_REAL=$(readlink -f "$USB_PATH" 2>/dev/null || true)
[ -n "$USB_REAL" ] || fail "cannot resolve selected USB sysfs object: $USB_PATH"
note "USB enumeration OK: $(basename "$USB_PATH") CAFE:F1D0 devnum=$USB_DEVNUM"

HID_IF=''
# Device publication and interface binding are separate sysfs phases.  A new
# CAFE:F1D0 device can be visible before Linux has created <device>:<ifnum>.
# Wait for the HID interface while continuing to prove the presenter is alive.
for ((i=0; i<VUSB_LIVE_TIMEOUT*10; i++)); do
  if ! kill -0 "$PRESENTER_PID" 2>/dev/null; then
    cat "$LOG" >&2 || true
    [ ! -s "$TRACE" ] || cat "$TRACE" >&2
    fail "presenter exited before HID interface binding completed"
  fi
  current_devnum=$(cat "$USB_PATH/devnum" 2>/dev/null || printf '?')
  [ "$current_devnum" = "$USB_DEVNUM" ] || fail "selected USB generation changed during HID binding: expected devnum=$USB_DEVNUM got=$current_devnum"
  for intf in "$USB_PATH":*; do
    [ -f "$intf/bInterfaceClass" ] || continue
    cls=$(tr '[:upper:]' '[:lower:]' <"$intf/bInterfaceClass")
    if [ "$cls" = "03" ]; then HID_IF=$intf; break; fi
  done
  [ -n "$HID_IF" ] && break
  sleep 0.1
done
if [ -z "$HID_IF" ]; then
  note "presenter trace at HID-interface timeout"
  [ ! -s "$TRACE" ] || sed -n '1,260p' "$TRACE" >&2
  note "presenter stdout/stderr at HID-interface timeout"
  sed -n '1,220p' "$LOG" >&2 || true
  note "enumerated sysfs device state"
  for f in idVendor idProduct bDeviceClass bNumConfigurations configuration bConfigurationValue; do
    [ -r "$USB_PATH/$f" ] && printf '  %s=%s\n' "$f" "$(cat "$USB_PATH/$f")" >&2
  done
  note "kernel interfaces under $(basename "$USB_PATH")"
  find "$(dirname "$USB_PATH")" -maxdepth 1 -name "$(basename "$USB_PATH"):*" -printf '  %f\n' 2>/dev/null >&2 || true
  fail "device enumerated but no HID class interface bound within ${VUSB_LIVE_TIMEOUT}s"
fi
HID_IF_REAL=$(readlink -f "$HID_IF" 2>/dev/null || true)
[ -n "$HID_IF_REAL" ] || fail "cannot resolve HID interface sysfs object: $HID_IF"
note "HID interface OK: $(basename "$HID_IF")"

HIDRAW=''
base=$(basename "$USB_PATH")
# hidraw publication follows interface creation and may lag it as the HID
# driver probes.  Poll it independently rather than sampling once.
for ((i=0; i<VUSB_LIVE_TIMEOUT*10; i++)); do
  if ! kill -0 "$PRESENTER_PID" 2>/dev/null; then
    cat "$LOG" >&2 || true
    [ ! -s "$TRACE" ] || cat "$TRACE" >&2
    fail "presenter exited before hidraw binding completed"
  fi
  current_devnum=$(cat "$USB_PATH/devnum" 2>/dev/null || printf '?')
  [ "$current_devnum" = "$USB_DEVNUM" ] || fail "selected USB generation changed during hidraw binding: expected devnum=$USB_DEVNUM got=$current_devnum"
  for h in "$VUSB_SYSFS_ROOT"/class/hidraw/hidraw*; do
    [ -e "$h" ] || [ -L "$h" ] || continue
    class_token=$(hidraw_class_token "$h" || true)
    [ -n "$class_token" ] || continue
    # A class object that existed before presenter launch cannot be evidence for
    # this run, even if path reuse later makes its device symlink resolve to the
    # new interface.  Require a newly published/rebound class generation.
    if grep -Fqx "$class_token" "$HIDRAW_BASELINE"; then continue; fi
    target=$(readlink -f "$h/device" 2>/dev/null || true)
    case "$target" in
      "$HID_IF_REAL"|"$HID_IF_REAL"/*)
        candidate="$VUSB_DEV_ROOT/$(basename "$h")"
        if [ -e "$candidate" ]; then HIDRAW=$candidate; break; fi
        ;;
    esac
  done
  [ -n "$HIDRAW" ] && break
  sleep 0.1
done
if [ -n "$HIDRAW" ]; then
  note "hidraw binding OK: $HIDRAW"
else
  [ ! -s "$TRACE" ] || sed -n '1,260p' "$TRACE" >&2
  fail "HID interface enumerated but no matching hidraw node bound within ${VUSB_LIVE_TIMEOUT}s"
fi

if command -v lsusb >/dev/null 2>&1; then
  note "lsusb identity: $(lsusb -d cafe:f1d0 2>/dev/null | head -1)"
fi

if command -v fido2-token >/dev/null 2>&1; then
  if fido2-token -L 2>/dev/null | grep -Fq "$HIDRAW"; then
    note "libfido2 discovery OK: $HIDRAW"
  else
    note "libfido2 is installed but did not list $HIDRAW (USB/HID enumeration still passed)"
  fi
else
  note "libfido2 discovery check SKIP: fido2-token not installed"
fi

note "raw-gadget trace follows"
[ ! -s "$TRACE" ] || sed -n '1,180p' "$TRACE"
note "presenter stdout/stderr follows"
sed -n '1,120p' "$LOG"
note "PASS USB host enumeration + HID/hidraw binding"
