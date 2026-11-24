#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
native="$root/src/xtp_rexx_native.cpp"
manager="$root/rexx/XtpNamedServices.cls"
for sym in xtpNativeSendService xtpNativeListenerOpenServices xtpNativeListenerLastService; do
  grep -q "REXX_TYPED_ROUTINE(${sym}, ${sym})" "$native" || { echo "FAIL missing routine registration: $sym" >&2; exit 1; }
done
awk '
  /^::method listener$/ { in_listener=1; next }
  in_listener && /^  expose / {
    if ($0 ~ /planner/ && $0 ~ /operatingState/) ok=1
    exit
  }
  END { exit(ok ? 0 : 1) }
' "$manager" || { echo "FAIL named-service listener does not expose planner operatingState" >&2; exit 1; }
echo "PASS ooRexx named-service routine registration and manager scope"
