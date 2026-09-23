#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT/tools/runtime_common.sh"
REXX=$(av9_find_rexx || true)
ver='missing'; [ -n "$REXX" ] && ver=$($REXX -v 2>&1 | sed -n '1p' || true)
printf 'schema\taudio.v9.worker.discovery/1\n'
printf 'hostname\t%s\n' "$(hostname 2>/dev/null || printf unknown)"
printf 'architecture\t%s\n' "$(uname -m 2>/dev/null || printf unknown)"
printf 'kernel\t%s\n' "$(uname -sr 2>/dev/null || printf unknown)"
printf 'libc\t%s\n' "$(av9_glibc)"
printf 'oorexx_path\t%s\n' "${REXX:-missing}"
printf 'oorexx_version\t%s\n' "$ver"
for c in unzip sha256sum ffmpeg gcc g++ readelf; do p=$(command -v "$c" 2>/dev/null || true); printf 'command:%s\t%s\n' "$c" "${p:-missing}"; done
printf 'disk_kib_free\t%s\n' "$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
