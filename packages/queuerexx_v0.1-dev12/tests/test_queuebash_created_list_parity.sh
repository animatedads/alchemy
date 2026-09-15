#!/usr/bin/env bash
set -euo pipefail
QB_ROOT="${QUEUEREXX_QUEUEBASH_144_ROOT:?set QUEUEREXX_QUEUEBASH_144_ROOT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=/dev/null
source "$QB_ROOT/queuebash.sh" >/dev/null
out="$(queue submit qb-created-parity --runner direct -- /bin/printf '%s\n' 'space value')"
qid="$(printf '%s\n' "$out" | awk '/^Submitted /{print $2; exit}')"
[[ -n "$qid" ]]
qb_json="$(queue list --json)"
qrx_json="$(rexx ../bin/queuerexx.rex list --json)"
python3 - "$qid" "$qb_json" "$qrx_json" <<'PY'
import json,sys
qid=sys.argv[1]
qb=json.loads(sys.argv[2]); qrx=json.loads(sys.argv[3])
qm=[j for j in qb.get('jobs',[]) if j.get('qid')==qid]
rm=[j for j in qrx.get('jobs',[]) if j.get('qid')==qid]
assert len(qm)==1 and len(rm)==1,(qm,rm)
assert qm[0] == rm[0],(qm[0],rm[0])
print('PASS QueueBash-created job list JSON object is exact in QueueRexx')
PY
