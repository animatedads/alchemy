#!/usr/bin/env bash
# Native ooRexx dispatch plus timeout receipt; no live SSH or privileged access.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
export HOME="$T" XDG_CONFIG_HOME="$T/config"
rexx=${REXX_BIN:-rexx}
cat > "$T/slow.py" <<'PY'
import time
time.sleep(30)
PY
run() { "$rexx" "$root/Computer" "$*"; }
set +e
draft=$(run "job draft slow local --timeout 1 -- /usr/bin/python3 $T/slow.py"); rc=$?
set -e
[[ $rc == 3 ]]
review=$(printf '%s\n' "$draft" | sed -nE 's/.*job approve ([a-zA-Z0-9_-]{32}) -- .*/\1/p' | head -1)
[[ ${#review} == 32 ]]
set +e
approval=$(run "job approve $review -- /usr/bin/python3 $T/slow.py"); rc=$?
set -e
[[ $rc == 3 ]]
activation=$(printf '%s\n' "$approval" | sed -n 's/^NOT REGISTERED until: Computer confirm //p')
[[ ${#activation} == 32 ]]
run "confirm $activation" >/dev/null
set +e
preview=$(run 'job start slow'); rc=$?
set -e
[[ $rc == 3 ]]
token=$(printf '%s\n' "$preview" | sed -n 's/^CONFIRM_RUN=Computer confirm //p')
[[ ${#token} == 32 ]]
set +e
out=$(run "confirm $token"); rc=$?
set -e
[[ $rc == 4 && $out == *'RESULT status=TIMEOUT rc=124'* && $out == *'TERMINATION='* ]]
run_id=$(printf '%s\n' "$out" | sed -n 's/^JOB_RESULT_COMMAND=Computer job result //p')
[[ -n $run_id ]]
meta=$(run "--json job result $run_id")
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); t=d["termination"]; assert t["termination_attempt"] and t["termination_scope"]=="posix_process_group" and d["status"]=="TIMEOUT" and d["child_rc"]==124' "$meta"
echo 'PASS native ooRexx dev10 timeout receipt'
