#!/bin/sh
# Alchemy Autobuild v0.5.1 acceptance. Starts the real program (the gap that let v0.5 ship broken),
# then re-runs v0.5's own branch-inbox tests unchanged.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(cd "$HERE/../.." && pwd)}
cd "$HERE"
python3 -m unittest -v tests.test_end_to_end
cd "$REPO/packages/alchemy_autobuild_v0.5"
python3 -m unittest -v tests.test_branch_inbox
