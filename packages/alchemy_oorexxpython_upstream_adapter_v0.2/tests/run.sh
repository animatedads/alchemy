#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$root/tests/contract_static.py"
export PYTHONPATH="$root/python${PYTHONPATH:+:$PYTHONPATH}"
export REXX_PATH="$root/rexx${REXX_PATH:+:$REXX_PATH}"
python3 "$root/tests/smoke.py"
rexx "$root/tests/smoke.rex"
