#!/bin/sh
set -eu
cd "$(dirname "$0")"
sh ./run_native.sh
if command -v zip >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
  sh ./run_interop.sh
else
  echo 'SKIP ZIP reference interoperability: zip/unzip not found'
fi
