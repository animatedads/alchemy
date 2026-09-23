#!/bin/sh
set -eu
cd "$(dirname "$0")"
./run_native.sh
./run_zstd_native.sh

if command -v gzip >/dev/null 2>&1; then
  ./run_interop.sh
else
  echo 'SKIP external gzip interoperability: gzip not found'
fi

if command -v zstd >/dev/null 2>&1; then
  ./run_zstd_interop.sh
else
  echo 'SKIP external Zstandard interoperability: zstd not found'
fi

if [ -n "${FOREIGN_RUNTIME_ROOT:-}" ]; then
  ./run_foreign_zstd.sh
else
  echo 'SKIP Foreign Runtime/libzstd qualification: FOREIGN_RUNTIME_ROOT not set'
fi
