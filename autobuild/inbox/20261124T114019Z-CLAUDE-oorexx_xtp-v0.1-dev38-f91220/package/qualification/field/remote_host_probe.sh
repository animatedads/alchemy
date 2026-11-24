#!/usr/bin/env bash
set -euo pipefail
BIN=${1:?usage: remote_host_probe.sh /path/to/xtp-local}
if [[ ! -x "$BIN" ]]; then echo 'ERROR binary_not_executable'; exit 2; fi
printf 'HOST='; hostname -s 2>/dev/null || hostname
printf 'KERNEL='; uname -r
printf 'UID='; id -u
"$BIN" probe
if command -v ip >/dev/null 2>&1; then
  DEF=$(ip -o route show default 2>/dev/null | head -1 || true)
  IFACE=$(awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}' <<<"$DEF")
  if [[ -n "$IFACE" ]]; then
    printf 'DEFAULT_IFACE=%s\n' "$IFACE"
    MAC=$(cat "/sys/class/net/$IFACE/address" 2>/dev/null || true)
    [[ -n "$MAC" ]] && printf 'DEFAULT_MAC=%s\n' "$MAC"
  fi
fi
