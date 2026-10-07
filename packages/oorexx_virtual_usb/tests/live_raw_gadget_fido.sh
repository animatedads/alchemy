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
  rm -f "$BASELINE"
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
note "USB enumeration OK: $(basename "$USB_PATH") CAFE:F1D0 devnum=$(cat "$USB_PATH/devnum" 2>/dev/null || printf '?')"

HID_IF=''
for i in "$USB_PATH":*; do
  [ -f "$i/bInterfaceClass" ] || continue
  cls=$(tr '[:upper:]' '[:lower:]' <"$i/bInterfaceClass")
  if [ "$cls" = "03" ]; then HID_IF=$i; break; fi
done
if [ -z "$HID_IF" ]; then
  note "presenter trace at HID-interface failure"
  [ ! -s "$TRACE" ] || sed -n '1,260p' "$TRACE" >&2
  note "presenter stdout/stderr at HID-interface failure"
  sed -n '1,220p' "$LOG" >&2 || true
  note "enumerated sysfs device state"
  for f in idVendor idProduct bDeviceClass bNumConfigurations configuration bConfigurationValue; do
    [ -r "$USB_PATH/$f" ] && printf '  %s=%s\n' "$f" "$(cat "$USB_PATH/$f")" >&2
  done
  note "kernel interfaces under $(basename "$USB_PATH")"
  find "$(dirname "$USB_PATH")" -maxdepth 1 -name "$(basename "$USB_PATH"):*" -printf '  %f\n' 2>/dev/null >&2 || true
  fail "device enumerated but no HID class interface was found"
fi
note "HID interface OK: $(basename "$HID_IF")"

HIDRAW=''
base=$(basename "$USB_PATH")
for h in "$VUSB_SYSFS_ROOT"/class/hidraw/hidraw*; do
  [ -e "$h" ] || continue
  target=$(readlink -f "$h/device" 2>/dev/null || true)
  case "$target" in
    *"/$base/"*|*"/$base:"*) HIDRAW="$VUSB_DEV_ROOT/$(basename "$h")"; break ;;
  esac
done
if [ -n "$HIDRAW" ] && [ -e "$HIDRAW" ]; then
  note "hidraw binding OK: $HIDRAW"
else
  fail "HID interface enumerated but no matching hidraw node was found"
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
