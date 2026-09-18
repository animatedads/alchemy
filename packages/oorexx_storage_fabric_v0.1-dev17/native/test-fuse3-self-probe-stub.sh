#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${TMPDIR:-/tmp}/storage-fuse3-stub-probe-$$
trap 'rm -f "$OUT"' EXIT
cc -std=c11 -O2 -Wall -Wextra -Werror -I"$ROOT/tests/fuse3_stub" \
  "$ROOT/native/storage_fuse3.c" "$ROOT/tests/fuse3_stub/fuse_stub.c" -o "$OUT"
out=$($OUT --storage-fuse-probe)
printf '%s\n' "$out"
grep -Fq 'storage-fuse3.probe/1' <<<"$out"
grep -Fq 'api=storage.fabric.fuse.native/0.1' <<<"$out"
grep -Fq 'protocol=SF1' <<<"$out"
grep -Fq 'libfuse_runtime=399' <<<"$out"
echo 'PASS storage_fuse3 self-probe contract against linked FUSE3 stub'