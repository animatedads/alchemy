#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
${CXX:-g++} -std=c++17 -Wall -Wextra -Werror -I"$ROOT/include" "$ROOT/tests/test_priority.cpp" "$ROOT/lib/libxtp.a" -pthread -o "$ROOT/tests/test_priority.bin"
"$ROOT/tests/test_priority.bin"
