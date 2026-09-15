#!/usr/bin/env bash
set -euo pipefail
[[ "$(id -u)" == 0 ]] || { echo 'SKIP lock permission distinction (not root)'; exit 0; }
id nobody >/dev/null 2>&1 || { echo 'SKIP lock permission distinction (nobody unavailable)'; exit 0; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/locks/state" "$tmp/logs/queue-state-reconcile" "$tmp/pending/p0999999990" "$tmp/running"
chown -R nobody "$tmp"
cat > "$tmp/pending/p0999999990/permjob.job" <<'JOB'
JOB_ID=permjob
JOB_NAME=permjob
PRIORITY=10
COMMAND=( true )
JOB
chown -R nobody "$tmp/pending" "$tmp/running"
chown root:root "$tmp/locks/state"
chmod 755 "$tmp/locks/state"
out="$(runuser -u nobody -- env PATH="$PATH" LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" REXX_HOME="${REXX_HOME:-}" REXX_PATH="../src${REXX_PATH:+:$REXX_PATH}" rexx test_lock_permission.rex "$tmp")"
status="$(printf '%s\n' "$out" | sed -n '1p')"
detail="$(printf '%s\n' "$out" | sed -n '2p')"
transition_status="$(printf '%s\n' "$out" | sed -n '3p')"
[[ "$status" == "3" ]]
[[ "$detail" == *'not writable'* ]]
[[ "$transition_status" == "11" ]]
echo 'PASS lock permission denied is distinct from timeout'
