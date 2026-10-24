#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
export XDG_CONFIG_HOME="$T/cfg" HOME="$T"
rexx=${REXX_BIN:-rexx}
run() { "$rexx" "$root/Computer" "$*"; }
mkdir -p "$T/work"
cat > "$T/create.py" <<'PY'
from pathlib import Path
import sys, time
workspace = Path(sys.argv[1]); large = workspace / 'temporary.dat'
large.write_bytes(b'X' * 11000000)
print('ERROR: intentional test output')
time.sleep(0.4)
large.unlink()
PY
# Native IntentionService job registration (existing approval workflow)
set +e
draft=$(run "job draft pressure local --timeout 4 -- python3 $T/create.py $T/work"); rc=$?
set -e
[[ $rc == 3 ]]
review_token=$(printf '%s\n' "$draft" | sed -nE 's/.*job approve ([A-Za-z0-9_-]{32}) -- .*/\1/p' | head -1)
[[ ${#review_token} == 32 ]]
set +e
attest=$(run "job approve $review_token -- python3 $T/create.py $T/work"); rc=$?
set -e
[[ $rc == 3 ]]
activation=$(printf '%s\n' "$attest" | sed -n 's/^NOT REGISTERED until: Computer confirm //p')
output=$(run "confirm $activation")
printf "%s\n" "$output" | grep -q JOB_REGISTERED
# Attach absolute space budget (exact user scenario) through separate reviewed policy
set +e
preview=$(run "job exception register pressure runaway_space $T/work 10 meg"); rc=$?
set -e
[[ $rc == 3 && "$preview" == *'JOB_EXCEPTION_PREVIEW'* ]]
token=$(printf '%s\n' "$preview" | sed -n 's/^Computer confirm //p')
output=$(run "confirm $token")
printf "%s\n" "$output" | grep -q JOB_EXCEPTION_REGISTERED
set +e
preview=$(run 'job exception register pressure output_contains "ERROR:" stdout'); rc=$?
set -e
[[ $rc == 3 ]]
token=$(printf '%s\n' "$preview" | sed -n 's/^Computer confirm //p')
output=$(run "confirm $token")
printf "%s\n" "$output" | grep -q JOB_EXCEPTION_REGISTERED
rules=$(run 'job exceptions pressure')
[[ "$rules" == *runaway_space* && "$rules" == *output_contains* ]]
# Run is not executed before explicit confirm
set +e
preview=$(run 'job run pressure'); rc=$?
set -e
[[ $rc == 3 && "$preview" == *'NOT EXECUTED'* ]]
token=$(printf '%s\n' "$preview" | sed -n 's/^CONFIRM_RUN=Computer confirm //p')
set +e
answer=$(run "confirm $token"); rc=$?
set -e
[[ $rc == 6 && "$answer" == *'EXCEPTION type=runaway_space'* && "$answer" == *'EXCEPTION type=output_contains'* ]]
run_id=$(printf '%s\n' "$answer" | sed -n 's/^JOB_RESULT_COMMAND=Computer job result //p')
[[ "$run_id" == computer-job-pressure-* ]]
record=$(run "--json job result $run_id")
python3 - "$record" <<'PY'
import json,sys
r=json.loads(sys.argv[1]); assert r['child_rc']==0 and r['status']=='EXITED'
e=r['exceptions']; assert e['count']==2 and e['observation_complete']
space=[a for a in e['raised'] if a['type']=='runaway_space'][0]
assert space['observed']['size_bytes']==11000000
assert any(a['type']=='output_contains' for a in e['raised'])
PY
output=$(run "job explain $run_id")
printf "%s\n" "$output" | grep -q 'EXCEPTIONS='
echo 'PASS native ooRexx dev7 run-scoped exceptions (11 meg breach and ERROR: output)'
