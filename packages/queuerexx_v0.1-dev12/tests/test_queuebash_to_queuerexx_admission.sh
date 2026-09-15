#!/usr/bin/env bash
set -euo pipefail
QB_ROOT="${QUEUEREXX_QUEUEBASH_144_ROOT:?set QUEUEREXX_QUEUEBASH_144_ROOT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=/dev/null
source "$QB_ROOT/queuebash.sh" >/dev/null
out="$(queue submit qb-to-qrx --runner direct -- /bin/true)"
qid="$(printf '%s\n' "$out" | awk '/^Submitted /{print $2; exit}')"
[[ -n "$qid" ]]
rexx test_claim_queuebash_job.rex "$tmp" "$qid"
qb_json="$(queue list --json)"
python3 - "$qid" "$qb_json" <<'PY'
import json,sys
qid=sys.argv[1]; d=json.loads(sys.argv[2])
m=[j for j in d.get('jobs',[]) if j.get('qid')==qid]
assert len(m)==1 and m[0].get('state')=='running',m
print('PASS QueueBash sees QueueRexx typed admission result as running')
PY
