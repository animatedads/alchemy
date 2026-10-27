#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
bash -n "$ROOT/bin/qualify.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for phase in native bsf jdorfx; do
  set +e
  env -u OO_ROOT -u BSF_HOME -u BSF_JAR -u BSF_NATIVE_LIBRARY bash "$ROOT/bin/qualify.sh" "$phase" >"$tmp/out" 2>&1
  rc=$?
  set -e
  [[ $rc -eq 2 ]] || { cat "$tmp/out"; exit 1; }
  grep -Fq 'OO_ROOT must be an absolute' "$tmp/out" || { cat "$tmp/out"; exit 1; }
done
set +e
bash "$ROOT/bin/qualify.sh" unexpected >"$tmp/out" 2>&1
rc=$?
set -e
[[ $rc -eq 2 ]] || { cat "$tmp/out"; exit 1; }
echo 'PASS syntax and four fail-closed preflight cases; runtime NOT_RUN'
