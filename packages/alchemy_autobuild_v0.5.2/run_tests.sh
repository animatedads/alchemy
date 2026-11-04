#!/bin/sh
# Alchemy Autobuild v0.5.2 acceptance. Author: Claude (Opus 5.5), 2026-11-04. Architecture: Tom Dyer.
# v0.5.2's own file-mode tests, then v0.5.1's acceptance (which re-runs v0.5's) unchanged.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(cd "$HERE/../.." && pwd)}
export ALCHEMY_REPO_ROOT="$REPO"
cd "$HERE"
python3 -m unittest -v tests.test_file_modes
sh "$REPO/packages/alchemy_autobuild_v0.5.1/run_tests.sh"
