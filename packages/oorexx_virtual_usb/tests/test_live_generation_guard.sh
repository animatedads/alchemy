#!/bin/bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/oorexx-vusb-generation-test.XXXXXX)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

SYS="$TMP/sys"
DEV="$TMP/dev"
mkdir -p "$SYS/class/udc/dummy_udc.0" "$SYS/bus/usb/devices" "$SYS/class/hidraw" "$DEV"
printf 'USB_UDC_NAME=dummy_udc\n' >"$SYS/class/udc/dummy_udc.0/uevent"
printf 'not attached\n' >"$SYS/class/udc/dummy_udc.0/state"

# A stale device is deliberately present before this qualification run.
mkdir -p "$SYS/bus/usb/devices/5-1"
printf 'cafe\n' >"$SYS/bus/usb/devices/5-1/idVendor"
printf 'f1d0\n' >"$SYS/bus/usb/devices/5-1/idProduct"
printf '2\n' >"$SYS/bus/usb/devices/5-1/devnum"
printf '00\n' >"$SYS/bus/usb/devices/5-1/bDeviceClass"
printf '1\n' >"$SYS/bus/usb/devices/5-1/bNumConfigurations"
printf '\n' >"$SYS/bus/usb/devices/5-1/configuration"
printf '\n' >"$SYS/bus/usb/devices/5-1/bConfigurationValue"

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

# Turn the same sysfs path into a new USB generation after the presenter has
# started. Reusing path 5-1 is intentional: only devnum changes prove this is
# a new enumeration rather than the stale baseline generation.
(
  sleep 0.4
  printf '3\n' >"$SYS/bus/usb/devices/5-1/devnum"
  mkdir -p "$SYS/bus/usb/devices/5-1:1.0"
  printf '03\n' >"$SYS/bus/usb/devices/5-1:1.0/bInterfaceClass"
  mkdir -p "$SYS/class/hidraw/hidraw0" "$DEV"
  ln -sfn "$SYS/bus/usb/devices/5-1:1.0" "$SYS/class/hidraw/hidraw0/device"
  : >"$DEV/hidraw0"
) &
UPDATER=$!

out=$(REXX="$FAKE_REXX" \
  OOREXX_VUSB_RAW_GADGET_PATH=/dev/null \
  OOREXX_VUSB_UDC_DRIVER=dummy_udc \
  OOREXX_VUSB_UDC_DEVICE=dummy_udc.0 \
  VUSB_SYSFS_ROOT="$SYS" \
  VUSB_DEV_ROOT="$DEV" \
  VUSB_LIVE_TIMEOUT=3 \
  "$ROOT/tests/live_raw_gadget_fido.sh" 2>&1)
wait "$UPDATER"

printf '%s\n' "$out" | grep -Fq 'pre-existing CAFE:F1D0 generations will not count as this run:'
printf '%s\n' "$out" | grep -Fq 'presenter ownership OK:'
printf '%s\n' "$out" | grep -Fq 'USB enumeration OK: 5-1 CAFE:F1D0 devnum=3'
printf '%s\n' "$out" | grep -Fq 'HID interface OK: 5-1:1.0'
printf '%s\n' "$out" | grep -Fq 'PASS USB host enumeration + HID/hidraw binding'

echo 'VIRTUAL USB LIVE GENERATION GUARD: OK'
