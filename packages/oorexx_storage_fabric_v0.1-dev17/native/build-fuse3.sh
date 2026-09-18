#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
if ! pkg-config --exists fuse3; then
  echo 'libfuse3 development files not found (pkg-config fuse3)' >&2
  exit 2
fi
if ! pkg-config --atleast-version=3.5 fuse3; then
  echo 'libfuse3 >= 3.5 is required for FUSE_USE_VERSION 35' >&2
  exit 2
fi
CC=${CC:-cc}
OUT=${STORAGE_FUSE_OUTPUT:-$ROOT/build/storage-fuse3}
mkdir -p "$(dirname "$OUT")"
# The package owns source/recipe; Preferred Packager owns whether this target
# reuses a supplied derivative or executes this recipe and seals the result.
"$CC" -std=c11 -O2 -Wall -Wextra -Werror native/storage_fuse3.c \
  $(pkg-config --cflags --libs fuse3) -o "$OUT"
chmod 755 "$OUT"
printf 'built %s\n' "$OUT"
"$ROOT/native/probe-fuse3.sh" "$OUT"