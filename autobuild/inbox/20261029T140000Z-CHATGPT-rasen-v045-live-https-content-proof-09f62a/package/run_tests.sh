#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m compileall -q website/tools website/tests handoff/tests
bash -n website/deploy/site_contract_probe.sh
python3 -m py_compile website/deploy/public_https_integrity_probe.py
bash -n handoff/deployment/deploy.sh
python3 -m unittest discover -s website/tests -p 'test_site.py' -v
python3 -m unittest discover -s handoff/tests -p 'test_*.py' -v
python3 website/tools/site.py validate
# Production build is intentionally denied, including on fully passing test runs.
if python3 website/tools/site.py build --mode production >/dev/null 2>&1; then
  echo 'FAIL: production gate accepted unapproved site' >&2
  exit 1
fi
