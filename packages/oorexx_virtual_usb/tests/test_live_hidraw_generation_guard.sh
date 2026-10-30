#!/bin/bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/oorexx-vusb-hidraw-generation.XXXXXX)
LIVE_PID=''
cleanup() {
  set +e
  [ -z "$LIVE_PID" ] || kill "$LIVE_PID" 2>/dev/null || true
  [ -z "$LIVE_PID" ] || wait "$LIVE_PID" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

SYS="$TMP/sys"
DEV="$TMP/dev"
PHYS="$SYS/devices/test/usb5/5-1"
INTF="$PHYS/5-1:1.0"
HIDNODE="$INTF/0003:CAFE:F1D0.0001"
HIDRAW_REAL="$HIDNODE/hidraw/hidraw7"
mkdir -p "$SYS/class/udc/dummy_udc.0" "$SYS/bus/usb/devices" "$SYS/class/hidraw" "$DEV"
printf 'USB_UDC_NAME=dummy_udc\n' >"$SYS/class/udc/dummy_udc.0/uevent"
printf 'not attached\n' >"$SYS/class/udc/dummy_udc.0/state"

publish_device() {
  local devnum=$1
  mkdir -p "$PHYS"
  printf 'cafe\n' >"$PHYS/idVendor"
  printf 'f1d0\n' >"$PHYS/idProduct"
  printf '%s\n' "$devnum" >"$PHYS/devnum"
  printf '00\n' >"$PHYS/bDeviceClass"
  printf '1\n' >"$PHYS/bNumConfigurations"
  printf '\n' >"$PHYS/configuration"
  printf '\n' >"$PHYS/bConfigurationValue"
  ln -sfn "$PHYS" "$SYS/bus/usb/devices/5-1"
}

publish_interface_target() {
  mkdir -p "$HIDRAW_REAL"
  printf '03\n' >"$INTF/bInterfaceClass"
  ln -sfn "$INTF" "$SYS/bus/usb/devices/5-1:1.0"
  ln -sfn "$HIDNODE" "$HIDRAW_REAL/device"
}

# Seed an old FIDO generation and a hidraw class entry.  The class symlink and
# /dev node deliberately survive path reuse below.  Once the same physical path
# is recreated, a path-only matcher would incorrectly accept this stale class
# object before the class entry itself has been rebound.
publish_device 2
publish_interface_target
ln -s "$HIDRAW_REAL" "$SYS/class/hidraw/hidraw7"
: >"$DEV/hidraw7"

FAKE_REXX="$TMP/rexx"
cat >"$FAKE_REXX" <<'REXXEOF'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" = "-v" ]; then
  echo 'Open Object Rexx Version 5.3.0 r13196 - Internal Test Version'
  exit 0
fi
case "${1:-}" in
  *test_dependency_environment.rex) exit 0 ;;
  *virtual_fido2_authenticator_raw.rex)
    printf 'PRESENTED provider=linux-raw-gadget udc=dummy_udc.0\n' >"$OOREXX_VUSB_READY_FILE"
    printf 'RAWGADGET TRACE: fake presenter owns test UDC\n' >"$OOREXX_VUSB_TRACE_FILE"
    while :; do sleep 1; done
    ;;
  *) exit 0 ;;
esac
REXXEOF
chmod +x "$FAKE_REXX"

REXX="$FAKE_REXX" \
OOREXX_VUSB_RAW_GADGET_PATH=/dev/null \
OOREXX_VUSB_UDC_DRIVER=dummy_udc \
OOREXX_VUSB_UDC_DEVICE=dummy_udc.0 \
VUSB_SYSFS_ROOT="$SYS" \
VUSB_DEV_ROOT="$DEV" \
VUSB_LIVE_TIMEOUT=5 \
"$ROOT/tests/live_raw_gadget_fido.sh" >"$TMP/out" 2>&1 &
LIVE_PID=$!

# Let the qualifier snapshot the old device/hidraw generations, then replace the
# USB generation while deliberately retaining the old hidraw class symlink.
sleep 0.4
rm -f "$SYS/bus/usb/devices/5-1" "$SYS/bus/usb/devices/5-1:1.0"
rm -rf "$PHYS"
publish_device 3
sleep 0.4
publish_interface_target

# At this point the stale hidraw class symlink resolves through the reused path
# and /dev/hidraw7 still exists.  dev10's path-only predicate can pass here.
# dev11 must remain alive until the class object itself is rebound.
sleep 2.0
if ! kill -0 "$LIVE_PID" 2>/dev/null; then
  cat "$TMP/out" >&2 || true
  echo 'VIRTUAL USB HIDRAW GENERATION GUARD: FAIL stale hidraw class generation was accepted' >&2
  exit 1
fi

# Simulate the HID core actually publishing/rebinding hidraw for the new device.
rm -f "$SYS/class/hidraw/hidraw7"
sleep 0.05
ln -s "$HIDRAW_REAL" "$SYS/class/hidraw/hidraw7"

wait "$LIVE_PID"
LIVE_PID=''

grep -Fq 'USB enumeration OK: 5-1 CAFE:F1D0 devnum=3' "$TMP/out"
grep -Fq 'HID interface OK: 5-1:1.0' "$TMP/out"
grep -Fq 'hidraw binding OK:' "$TMP/out"
grep -Fq 'PASS USB host enumeration + HID/hidraw binding' "$TMP/out"

echo 'VIRTUAL USB HIDRAW GENERATION GUARD: OK'
