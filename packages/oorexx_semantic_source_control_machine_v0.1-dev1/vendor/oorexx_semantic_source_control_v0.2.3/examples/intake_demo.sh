#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
REPO=${1:-/tmp/osc-demo-repo}
rm -rf "$REPO"

bin/osc baseline tests/fixtures/provider_v1 --repo "$REPO" --component DataStore --level 1
TP=$(cut -d'|' -f1 "$REPO/proposals.osc")
bin/osc proposal show "$TP" --repo "$REPO"
bin/osc proposal accept "$TP" --repo "$REPO" --reason production SQL result shape matters
bin/osc impact tests/fixtures/incoming_rollup.zip --repo "$REPO" --against tests/fixtures/work
