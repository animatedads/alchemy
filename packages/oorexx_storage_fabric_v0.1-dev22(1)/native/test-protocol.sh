#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
cc -std=c11 -O2 -Wall -Wextra -Werror -DSTORAGE_FUSE3_PROTOCOL_ONLY native/storage_fuse3.c -o build/storage-fuse3-protocol-test
./build/storage-fuse3-protocol-test
