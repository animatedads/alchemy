#!/usr/bin/env bash
set -euo pipefail
[[ "$(id -u)" == 0 ]] || { echo "SKIP root ownership (not root)"; exit 0; }
id nobody >/dev/null 2>&1 || { echo "SKIP root ownership (nobody unavailable)"; exit 0; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
chown nobody "$tmp"
mapfile -t paths < <(rexx test_root_ownership.rex "$tmp" nobody)
job="${paths[1]}"
[[ "$(stat -c %U "$tmp/locks")" == nobody ]]
[[ "$(stat -c %U "$tmp/locks/state")" == nobody ]]
[[ "$(stat -c %U "$tmp/logs/queue-state-reconcile")" == nobody ]]
[[ "$(stat -c %U "$job")" == nobody ]]
echo "PASS 0.18.144 root-created lock/reconcile paths inherit queue-root owner"
