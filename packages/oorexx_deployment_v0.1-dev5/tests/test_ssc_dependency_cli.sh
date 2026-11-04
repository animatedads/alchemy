#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${SSC_ROOT:?SSC_ROOT required}"
out=$(mktemp "${TMPDIR:-/tmp}/deployment-dependency-lock.XXXXXX")
trap 'rm -f "$out"' EXIT HUP INT TERM
"$ROOT/bin/resolve_ssc_dependencies.sh" \
  --ssc-root "$SSC_ROOT" \
  --consumer "$ROOT" \
  --entry src/SscDeploymentDependencies.cls \
  --provider "$SSC_ROOT" \
  --out "$out"
grep -F "component$(printf '\t')SemanticSourceControl$(printf '\t')5" "$out" >/dev/null
grep -F "package$(printf '\t')OorexxDeployment$(printf '\t')src/SscDeploymentDependencies.cls$(printf '\t')SemanticSourceControl.cls$(printf '\t')SemanticSourceControl" "$out" >/dev/null
echo 'PASS SSC dependency CLI/lock'
