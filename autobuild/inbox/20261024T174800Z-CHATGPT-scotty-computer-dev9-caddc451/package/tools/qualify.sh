#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -m py_compile "$root/src/"*.py "$root/.claude/hooks/computer_approval.py"
bash -n "$root/tools/install.sh" "$root/tests/"test_oorexx_*.sh "$root/adapters/sshnode.sh" "$root/adapters/cloudctl.sh"
python3 -m unittest discover -v -s "$root/tests" -p 'test_*.py'
# Run native suites serially by default to make failure attribution deterministic.
# A future change may enable parallel mode only after proving fixture isolation.
suites=(test_oorexx_integration test_oorexx_scopes_github_learn test_oorexx_jobs_documents test_oorexx_dev6 test_oorexx_dev7 test_oorexx_dev9)
for name in "${suites[@]}"; do
  echo "START native suite $name"
  "$root/tests/$name.sh"
  echo "PASS native suite $name"
done
echo 'PASS Computer qualification'
