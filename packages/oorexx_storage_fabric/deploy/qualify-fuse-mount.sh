#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MOUNT=${1:?usage: qualify-fuse-mount.sh MOUNTPOINT [STATE_DIR]}
STATE=${2:-/tmp/oorexx-storage-fuse-qualify}
[[ -c /dev/fuse ]] || { echo 'FAIL: /dev/fuse is not available on this target' >&2; exit 77; }
command -v fusermount3 >/dev/null 2>&1 || { echo 'FAIL: fusermount3 is required for kernel FUSE qualification' >&2; exit 77; }
command -v mountpoint >/dev/null 2>&1 || { echo 'FAIL: mountpoint is required for kernel FUSE qualification' >&2; exit 77; }
"$ROOT/native/probe-fuse3.sh" "$ROOT/build/storage-fuse3"
cleanup(){ "$ROOT/deploy/stop-fuse.sh" "$MOUNT" "$STATE" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
cleanup
"$ROOT/deploy/start-fuse.sh" "$MOUNT" "$STATE"
"$ROOT/deploy/fuse-soak.sh" "$MOUNT" 1
mountpoint -q "$MOUNT"
echo 'PASS storage-fuse3 live kernel mount qualification'
