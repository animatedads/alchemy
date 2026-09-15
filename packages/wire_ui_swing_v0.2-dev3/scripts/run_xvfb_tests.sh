#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "xvfb-run is required for virtual-display desktop tests" >&2
  exit 2
fi
xvfb-run -a "$ROOT/scripts/run_desktop_tests.sh"
"$ROOT/scripts/run_executable_jar_tests.sh"
