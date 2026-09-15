#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
test -f "$ROOT/packs/oorexx-ml-graph/articles/arch.ml-graph.boundary.json"
test -f "$ROOT/packs/oorexx-ml-graph/articles/arch.ml-graph.temporal-cylinder.json"
test -f "$ROOT/packs/oorexx-ml-graph/articles/demo.ml-graph.market.json"
grep -q 'Renderers explain ML evidence' "$ROOT/packs/oorexx-ml-graph/corpora/ml-graph.lessons.json"
echo 'PASS ooRexx ML Graph sphere structural test'
