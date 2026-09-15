#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
JAR="$ROOT/build/wire-ui-swing-v0.2-dev6.jar"

VERSION_OUTPUT="$(java -jar "$JAR" --version)"
[[ "$VERSION_OUTPUT" == "wire-ui-swing 0.2-dev6" ]]

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "xvfb-run is required for executable-JAR GUI smoke test" >&2
  exit 2
fi

SMOKE_OUTPUT="$(xvfb-run -a java -Djava.awt.headless=false -jar "$JAR" --smoke-window)"
grep -Fq 'wire-ui-swing 0.2-dev6 READY view=SEARCH revision=0' <<<"$SMOKE_OUTPUT"

# Exercise the exact no-argument launch form a user/double-click handler uses.
LOG="$ROOT/build/executable-jar-noargs.log"
rm -f "$LOG"
xvfb-run -a bash -c '
  set -euo pipefail
  java -jar "$1" >"$2" 2>&1 &
  pid=$!
  trap '\''kill "$pid" 2>/dev/null || true'\'' EXIT
  for _ in $(seq 1 50); do
    if grep -Fq "wire-ui-swing 0.2-dev6 READY view=SEARCH revision=0" "$2" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      trap - EXIT
      exit 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      cat "$2" >&2 || true
      exit 1
    fi
    sleep 0.1
  done
  cat "$2" >&2 || true
  exit 1
' bash "$JAR" "$LOG"

echo "PASS executable JAR manifest/version"
echo "PASS java -jar --smoke-window under Xvfb"
echo "PASS exact no-argument java -jar launch under Xvfb"
