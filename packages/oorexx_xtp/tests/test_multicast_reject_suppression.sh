#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
${CXX:-g++} -I"$ROOT/include" -O2 -std=c++17 -Wall -Wextra -Werror -pthread \
  "$ROOT/tests/test_multicast_reject_suppression.cpp" "$ROOT/lib/libxtp.a" -o "$TMP/test"
"$TMP/test"
