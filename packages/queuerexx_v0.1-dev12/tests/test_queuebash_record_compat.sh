#!/usr/bin/env bash
set -euo pipefail
QB_ROOT="${QUEUEREXX_QUEUEBASH_144_ROOT:?set QUEUEREXX_QUEUEBASH_144_ROOT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1
qid="$(rexx test_submit_for_queuebash.rex "$tmp")"
job="$(find "$tmp/pending" -type f -name "$qid.job" -print -quit)"
[[ -n "$job" && -f "$job" ]]
# Prove the generated record is legal QueueBash shell syntax and preserves exact argv.
set +u
# shellcheck source=/dev/null
source "$job"
set -u
[[ "${COMMAND[0]}" == "/bin/printf" ]]
[[ "${COMMAND[1]}" == '%s\n' ]]
[[ "${COMMAND[2]}" == "space value" ]]
[[ "${COMMAND[3]}" == '$HOME' ]]
[[ "${COMMAND[4]}" == '`uname`' ]]
[[ "${COMMAND[5]}" == "it's literal" ]]
[[ "$PWD_AT_SUBMIT" == "/tmp/space dir" ]]
# The production QueueBash parser/list surface must accept the QueueRexx record.
# shellcheck source=/dev/null
source "$QB_ROOT/queuebash.sh" >/dev/null
qb_json="$(queue list --json)"
qrx_json="$(rexx ../bin/queuerexx.rex list --json)"
python3 - "$qid" "$qb_json" "$qrx_json" <<'PY'
import json,sys
qid=sys.argv[1]
qb=json.loads(sys.argv[2]); qrx=json.loads(sys.argv[3])
qm=[j for j in qb.get('jobs',[]) if j.get('qid')==qid]
rm=[j for j in qrx.get('jobs',[]) if j.get('qid')==qid]
assert len(qm)==1, qm
assert len(rm)==1, rm
assert qm[0] == rm[0], (qm[0], rm[0])
print('PASS QueueBash sources QueueRexx record and list JSON job object is exact')
PY
