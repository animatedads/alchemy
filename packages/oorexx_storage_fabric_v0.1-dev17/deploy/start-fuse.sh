#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MOUNT=${1:?usage: start-fuse.sh MOUNTPOINT [STATE_DIR]}
STATE=${2:-/tmp/oorexx-storage-fuse}
SOCKET=${STORAGE_FUSE_SOCKET:-$STATE/rpc.sock}
BIN="$ROOT/build/storage-fuse3"
mkdir -p "$MOUNT" "$STATE"
chmod 700 "$STATE"

: "${REXX_PATH:?REXX_PATH must include ooRexx Unix Socket v0.6 and Foreign Runtime rexx directory}"

if [[ ! -x "$BIN" ]]; then
  if [[ "${STORAGE_FUSE_DEV_BUILD:-0}" == 1 ]]; then
    echo 'WARNING: developer opt-in build; package installations must receive a Packager-qualified derivative' >&2
    "$ROOT/native/build-fuse3.sh"
  else
    echo "storage-fuse3 foreign artefact is absent: $BIN" >&2
    echo 'Install through Preferred Packager, or set STORAGE_FUSE_DEV_BUILD=1 only in a developer source tree.' >&2
    exit 2
  fi
fi
"$ROOT/native/probe-fuse3.sh" "$BIN"

rm -f "$SOCKET"
(cd "$ROOT" && rexx bin/storage-fuse-rpcd.rex "$SOCKET") >"$STATE/rpcd.log" 2>&1 &
echo $! > "$STATE/rpcd.pid"
for _ in {1..100}; do [[ -S "$SOCKET" ]] && break; sleep .05; done
[[ -S "$SOCKET" ]] || { cat "$STATE/rpcd.log" >&2; exit 1; }

# -s is intentional for the first qualification: one kernel callback at a time.
# Per-open direct_io is forced by the native shim so the ooRexx generation
# engine, not kernel writeback caching, owns write ordering.
STORAGE_FUSE_SOCKET="$SOCKET" "$BIN" -f -s "$MOUNT" >"$STATE/fuse.log" 2>&1 &
echo $! > "$STATE/fuse.pid"

for _ in {1..100}; do mountpoint -q "$MOUNT" && break; sleep .05; done
if ! mountpoint -q "$MOUNT"; then
  cat "$STATE/fuse.log" >&2
  kill "$(cat "$STATE/rpcd.pid")" 2>/dev/null || true
  exit 1
fi
printf 'mounted %s\nrpc socket %s\nstate %s\n' "$MOUNT" "$SOCKET" "$STATE"