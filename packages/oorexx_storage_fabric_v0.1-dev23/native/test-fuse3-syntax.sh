#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cc -std=c11 -Wall -Wextra -Werror -fsyntax-only -Itests/fuse3_stub native/storage_fuse3.c
echo "PASS storage_fuse3 full adapter syntax against FUSE3 signature stub"
