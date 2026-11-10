#!/usr/bin/env bash
# Exercise dev5 intentions through the actual native ooRexx IntentionService.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
export HOME="$T" XDG_CONFIG_HOME="$T/config" COMPUTER_TEST_TRACE="$T/record.txt"
export COMPUTER_SSHNODE="$T/sshnode.sh"
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
cat > "$T/mycommand.sh" <<'PROGRAM'
#!/usr/bin/env bash
printf '%s\n' "$@"
PROGRAM
chmod 700 "$T/mycommand.sh"
run() { "$rexx" "$root/Computer" "$*"; }
# Confirm a two-stage registration and one-stage per-run action for a real local executable.
set +e
first=$(run "job draft localdemo local -- '$T/mycommand.sh' '--name' 'two words'"); rc=$?
set -e
[[ $rc == 3 && "$first" == *'NOT REGISTERED'* ]]
reviewtoken=$(printf '%s\n' "$first" | sed -nE 's/.*job approve ([a-zA-Z0-9_-]{32}) -- .*/\1/p' | head -1)
[[ ${#reviewtoken} == 32 ]]
set +e
review=$(run "job approve $reviewtoken -- '$T/mycommand.sh' '--name' 'two words'"); rc=$?
set -e
[[ $rc == 3 && "$review" == *'JOB_STRUCTURE_ATTESTED'* ]]
activate=$(printf '%s\n' "$review" | sed -n 's/^NOT REGISTERED until: Computer confirm //p')
[[ ${#activate} == 32 ]]
output=$(run "confirm $activate")
printf "%s\n" "$output" | grep -q '^JOB_REGISTERED'
set +e
preview=$(run 'job run localdemo'); rc=$?
set -e
[[ $rc == 3 && "$preview" == *'NOT EXECUTED'* ]]
execute=$(printf '%s\n' "$preview" | sed -n 's/^CONFIRM_RUN=Computer confirm //p')
[[ ${#execute} == 32 ]]
output=$(run "confirm $execute")
[[ "$output" == *'RESULT status=EXITED rc=0'* ]]
receipt=$(printf '%s\n' "$output" | sed -nE 's/^RECEIPT stdout=([^ ]+) stderr=.*/\1/p')
[[ $(cat "$receipt") == $'--name\ntwo words' ]]
set +e
replay=$(run "confirm $execute" 2>&1); rc=$?
set -e
[[ $rc == 4 && "$replay" == *'used or expired'* ]]
# Named node path, with no actual connection to remote infrastructure.
set +e
first=$(run "job draft remotedemo on ed209b -- printf %s 'some spaces; and \$dollar'"); rc=$?
set -e
[[ $rc == 3 && "$first" == *'ed209b'* ]]
reviewtoken=$(printf '%s\n' "$first" | sed -nE 's/.*job approve ([a-zA-Z0-9_-]{32}) -- .*/\1/p' | head -1)
set +e
review=$(run "job approve $reviewtoken -- printf %s 'some spaces; and \$dollar'"); rc=$?
set -e
[[ $rc == 3 && "$review" == *'JOB_STRUCTURE_ATTESTED'* ]]
activate=$(printf '%s\n' "$review" | sed -n 's/^NOT REGISTERED until: Computer confirm //p')
output=$(run "confirm $activate")
printf "%s\n" "$output" | grep -q '^JOB_REGISTERED'
set +e
preview=$(run 'job run remotedemo'); rc=$?
set -e
[[ $rc == 3 && "$preview" == *'REMOTE_EXECUTION=sshnode.sh'* ]]
execute=$(printf '%s\n' "$preview" | sed -n 's/^CONFIRM_RUN=Computer confirm //p')
output=$(run "confirm $execute")
printf "%s\n" "$output" | grep -q 'RESULT status=EXITED rc=0'
python3 - "$COMPUTER_TEST_TRACE" <<'PY'
import shlex,sys
args=open(sys.argv[1]).read().splitlines()
assert args[0]=='--job-id' and args[2]=='ed209b' and len(args)==4
assert shlex.split(args[3])==['printf','%s','some spaces; and $dollar']
PY
# Revocation is also confirmed and invalidates the definition.
set +e
revoke=$(run 'job revoke localdemo'); rc=$?
set -e
[[ $rc == 3 && "$revoke" == *'NOT REVOKED'* ]]
revoketoken=$(printf '%s\n' "$revoke" | sed -n 's/^Computer confirm //p')
[[ ${#revoketoken} == 32 ]]
output=$(run "confirm $revoketoken")
printf "%s\n" "$output" | grep -q '^JOB_REVOKED'
set +e
notthere=$(run 'job run localdemo' 2>&1); rc=$?
set -e
[[ $rc == 1 && "$notthere" == *'Unknown registered job'* ]]
# Source document read and safe member access are actually dispatched by ooRexx.
mkdir -p "$T/source"
printf '# Test guide\n' > "$T/source/README.md"
output=$(run "read document $T/source/README.md")
printf "%s\n" "$output" | grep -q '# Test guide'
python3 - "$T/source/archive.zip" <<'PY'
import sys,zipfile
with zipfile.ZipFile(sys.argv[1], 'w') as file:
    file.writestr('docs/README.md','# Archived guide\n')
PY
output=$(run "list documents in $T/source/archive.zip")
printf "%s\n" "$output" | grep -q 'docs/README.md'
output=$(run "read document docs/README.md in $T/source/archive.zip")
printf "%s\n" "$output" | grep -q '# Archived guide'
[[ ! -e "$T/source/docs/README.md" ]]
echo 'PASS native ooRexx learned jobs and document intentions'
