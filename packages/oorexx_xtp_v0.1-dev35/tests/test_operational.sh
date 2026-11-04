#!/bin/sh
set -eu
D="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
P="${OPERATIONAL_PLANNER_DIR:-$D/../oorexx_operational_degradation_planner_v0.1-dev2}"
make -C "$P" all >/dev/null
${CXX:-g++} -I"$D/include" -I"$P/include" -O2 -std=c++17 -Wall -Wextra -Werror "$D/tests/test_operational.cpp" "$D/lib/libxtp.a" "$P/lib/liboperational_planner.a" -lcrypto -pthread -o "$D/tests/test_operational.bin"
"$D/tests/test_operational.bin"
