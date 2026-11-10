#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
export XDG_CONFIG_HOME="$T/config" HOME="$T" COMPUTER_SSHNODE="$T/sshnode.sh" COMPUTER_TEST_TRACE="$T/remote_args.txt"
rexx=${REXX_BIN:-rexx}
cat > "$COMPUTER_SSHNODE" <<'ADAPTER'
#!/usr/bin/env bash
set -euo pipefail
case ed209b in
  ed209b) user=opc;;
esac
printf '%s\n' "$@" > "$COMPUTER_TEST_TRACE"
ADAPTER
chmod 700 "$COMPUTER_SSHNODE"
run() { "$rexx" "$root/Computer" "$*"; }
mkdir -p "$T/work/xtp-source" "$T/unrelated/xtp-wrong"
run "add $T/work to my find file locations as xtpwork" >/dev/null
findings=$(run 'find directories matching xtp in xtpwork')
[[ "$findings" == *"$T/work/xtp-source"* && "$findings" != *xtp-wrong* ]]
json=$(run '--json find directories matching xtp in xtpwork')
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["complete"] and d["count"]==1' "$json"
set +e
unknown=$(run 'find directories matching xtp in unknown' 2>&1); rc=$?
set -e
[[ $rc == 3 && "$unknown" == *'Unknown search scope'* ]]
set +e
draft=$(run 'job draft statuscheck local -- /usr/bin/uptime'); rc=$?
set -e
[[ $rc == 3 ]]
reviewtoken=$(printf '%s\n' "$draft" | sed -nE 's/.*job approve ([A-Za-z0-9_-]{32}) -- .*/\1/p' | head -1)
set +e
review=$(run "job approve $reviewtoken -- /usr/bin/uptime"); rc=$?
set -e
[[ $rc == 3 ]]
activation=$(printf '%s\n' "$review" | sed -n 's/^NOT REGISTERED until: Computer confirm //p')
output=$(run "confirm $activation")
printf "%s\n" "$output" | grep -q JOB_REGISTERED
# It must not be immediately reusable without a policy grant.
set +e
pending=$(run 'job run statuscheck'); rc=$?
set -e
[[ $rc == 3 && "$pending" == *'CONFIRM_RUN='* ]]
set +e
policy=$(run 'job policy statuscheck repeat-readonly'); rc=$?
set -e
[[ $rc == 3 && "$policy" == *'NOT CHANGED'* ]]
policytoken=$(printf '%s\n' "$policy" | sed -n 's/^Computer confirm //p')
[[ ${#policytoken} == 32 ]]
output=$(run "confirm $policytoken")
printf "%s\n" "$output" | grep -q JOB_POLICY_APPLIED
ran=$(run 'job run statuscheck')
[[ "$ran" == *'policy=repeat-readonly'* && "$ran" == *'RESULT status=EXITED rc=0'* ]]
run_id=$(printf '%s\n' "$ran" | sed -n 's/^JOB_RESULT_COMMAND=Computer job result //p')
[[ "$run_id" == computer-job-statuscheck-* ]]
output=$(run "job result $run_id")
printf "%s\n" "$output" | grep -q '"child_rc": 0'
output=$(run "job explain $run_id")
printf "%s\n" "$output" | grep -q 'EXPLANATION=child exited zero'
output=$(run "job stdout $run_id")
printf "%s\n" "$output" | grep -q 'JOB_STDOUT'
output=$(run "job history statuscheck")
printf "%s\n" "$output" | grep -q "$run_id"
run "--json job result $run_id" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["child_rc"]==0 and d["policy"]=="repeat-readonly"'
# A shell interpreter can be registered, but NEVER awarded repeat-readonly.
set +e
draft=$(run "job draft shelljob local -- /bin/sh -c 'echo unsafe'"); rc=$?
set -e
[[ $rc == 3 ]]
reviewtoken=$(printf '%s\n' "$draft" | sed -nE 's/.*job approve ([A-Za-z0-9_-]{32}) -- .*/\1/p' | head -1)
set +e
review=$(run "job approve $reviewtoken -- /bin/sh -c 'echo unsafe'"); rc=$?
set -e
[[ $rc == 3 ]]
activation=$(printf '%s\n' "$review" | sed -n 's/^NOT REGISTERED until: Computer confirm //p')
output=$(run "confirm $activation")
printf "%s\n" "$output" | grep -q JOB_REGISTERED
set +e
refusal=$(run 'job policy shelljob repeat-readonly' 2>&1); rc=$?
set -e
[[ $rc == 4 && "$refusal" == *'allowlisted diagnostic'* ]]
echo 'PASS native ooRexx dev6 receipts, search discovery and reusable diagnostics'
