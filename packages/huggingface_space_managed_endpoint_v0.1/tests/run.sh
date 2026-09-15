#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 -m py_compile "$ROOT/src/managed_compute_core.py" "$ROOT/src/managed_space_endpoints.py" "$ROOT/src/managed_smoke.py"
PYTHONPATH="$ROOT/src" REXXAPI_MANAGED_ENDPOINT_TEST_MODE=1 python3 -m pytest -q "$ROOT/tests"
