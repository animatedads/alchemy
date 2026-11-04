#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAB="$(mktemp -d)"
trap 'rm -rf -- "$LAB"' EXIT
PYTHON="${PYTHON:-python3}"
run() { "$PYTHON" "$HERE/virtual_ups.py" --dir "$LAB" "$@"; }
echo '=== Synthetic UPS: initial state ==='
run init --name ed209j-kl10 --simulate
echo '=== Synthetic power outage ==='
run mains off --simulate
echo '=== Simulate 24 minutes; threshold 20% ==='
run advance 1440 --simulate
echo '=== Restored mains ==='
run mains on --simulate
echo '=== Audit; no actual power affected ==='
run audit
