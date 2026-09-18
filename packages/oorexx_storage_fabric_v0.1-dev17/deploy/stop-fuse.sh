#!/usr/bin/env bash
set -euo pipefail
MOUNT=${1:?usage: stop-fuse.sh MOUNTPOINT [STATE_DIR]}
STATE=${2:-/tmp/oorexx-storage-fuse}
if mountpoint -q "$MOUNT"; then
  if command -v fusermount3 >/dev/null 2>&1; then fusermount3 -u "$MOUNT"; else umount "$MOUNT"; fi
fi
for f in fuse.pid rpcd.pid; do
  [[ -f "$STATE/$f" ]] && kill "$(cat "$STATE/$f")" 2>/dev/null || true
done
rm -f "$STATE/rpc.sock"