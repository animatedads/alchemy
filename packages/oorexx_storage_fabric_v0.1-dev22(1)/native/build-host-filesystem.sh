#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(dirname "$HERE")
mkdir -p "$ROOT/build"
CC=${CC:-cc}
"$CC" -std=c11 -O2 -Wall -Wextra -Werror "$HERE/storage_host_commit.c" -o "$ROOT/build/storage-host-commit"
"$ROOT/build/storage-host-commit" syncdir "$ROOT/build"
echo "PASS storage-host-commit build/self-sync"
