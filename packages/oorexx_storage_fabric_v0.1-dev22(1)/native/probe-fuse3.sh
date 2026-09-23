#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN=${1:-$ROOT/build/storage-fuse3}
[[ -x "$BIN" ]] || { echo "storage-fuse3 probe: binary absent or not executable: $BIN" >&2; exit 2; }
out=$($BIN --storage-fuse-probe) || { rc=$?; echo "storage-fuse3 probe execution failed rc=$rc" >&2; exit "$rc"; }
printf '%s\n' "$out"
grep -Fq 'storage-fuse3.probe/1' <<<"$out" || { echo 'foreign probe schema mismatch' >&2; exit 3; }
grep -Fq 'api=storage.fabric.fuse.native/0.1' <<<"$out" || { echo 'foreign native API mismatch' >&2; exit 4; }
grep -Fq 'protocol=SF1' <<<"$out" || { echo 'foreign RPC protocol mismatch' >&2; exit 5; }
grep -Fq 'io=direct_io' <<<"$out" || { echo 'foreign first-mount I/O contract mismatch' >&2; exit 6; }
echo 'PASS storage-fuse3 target probe'
