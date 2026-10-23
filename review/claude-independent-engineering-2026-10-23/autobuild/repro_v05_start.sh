#!/bin/sh
# Reproduce: alchemy_autobuild v0.5 cannot start the way its systemd unit starts it.
# Author: Claude (Opus 5.5), 2026-10-23. Usage: sh repro_v05_start.sh <alchemy repo root>
set -u
REPO=${1:?alchemy repository root}
cd /
echo "--- v0.5 (expected: ModuleNotFoundError: No module named 'git_sync')"
OUT=$(mktemp)
python3 "$REPO/packages/alchemy_autobuild_v0.5/alchemy_autobuild.py" --print-config > "$OUT" 2>&1
rc=$?
tail -3 "$OUT"; rm -f "$OUT"
echo "exit=$rc"
if [ -f "$REPO/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py" ]; then
  echo "--- v0.5.1 (expected: configuration printed, exit 0)"
  python3 "$REPO/packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py" --print-config > /dev/null 2>&1
  echo "exit=$?"
fi
echo "--- last autobuild result directory in Git"
ls "$REPO/autobuild/results" | sort | tail -1
