#!/usr/bin/env bash
set -euo pipefail
QB_ROOT="${QUEUEREXX_QUEUEBASH_144_ROOT:?set QUEUEREXX_QUEUEBASH_144_ROOT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1
qid="$(rexx test_submit_true_for_queuebash.rex "$tmp")"
[[ -f "$(find "$tmp/pending" -type f -name "$qid.job" -print -quit)" ]]
# shellcheck source=/dev/null
source "$QB_ROOT/queuebash.sh" >/dev/null
queue run >"$tmp/worker.out" 2>"$tmp/worker.err"
[[ -f "$tmp/done/$qid.job" ]]
[[ ! -e "$tmp/pending/$qid.job" ]]
# QueueRexx must read the terminal record written by QueueBash from the same root.
state="$(rexx ../bin/queuerexx.rex list --json | python3 -c 'import json,sys; q=sys.argv[1]; d=json.load(sys.stdin); print(next(j["state"] for j in d["jobs"] if j["qid"]==q))' "$qid")"
[[ "$state" == "done" ]]
echo "PASS QueueBash 0.18.144 executes QueueRexx-submitted job and QueueRexx reads terminal state"
