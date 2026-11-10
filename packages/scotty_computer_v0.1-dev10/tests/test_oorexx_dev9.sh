#!/usr/bin/env bash
# Native dispatch and authority-revalidation test; no live SSH.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
export HOME="$T" XDG_CONFIG_HOME="$T/config"
rexx=${REXX_BIN:-rexx}
cat > "$T/demo.py" <<'PY'
print('source was pinned')
PY
run() { "$rexx" "$root/Computer" "$*"; }
set +e
review=$(run "job draft pinned local -- /usr/bin/python3 $T/demo.py"); rc=$?
set -e
[[ $rc == 3 && $review == *'PINNED_FILES='* && $review == *'demo.py'* ]]
tok=$(printf '%s\n' "$review" | sed -nE 's/.*job approve ([a-zA-Z0-9_-]{32}) -- .*/\1/p' | head -1)
[[ ${#tok} == 32 ]]
set +e
approved=$(run "job approve $tok -- /usr/bin/python3 $T/demo.py"); rc=$?
set -e
[[ $rc == 3 && $approved == *'JOB_STRUCTURE_ATTESTED'* ]]
activation=$(printf '%s\n' "$approved" | sed -n 's/^NOT REGISTERED until: Computer confirm //p')
[[ ${#activation} == 32 ]]
registered=$(run "confirm $activation")
[[ $registered == *'JOB_REGISTERED'* ]]
set +e
preview=$(run 'job run pinned'); rc=$?
set -e
[[ $rc == 3 && $preview == *'demo.py'* ]]
execute=$(printf '%s\n' "$preview" | sed -n 's/^CONFIRM_RUN=Computer confirm //p')
[[ ${#execute} == 32 ]]
printf 'print("mutated after preview")\n' > "$T/demo.py"
set +e
blocked=$(run "confirm $execute" 2>&1); rc=$?
set -e
[[ $rc == 4 && $blocked == *'authority changed'* ]]
echo 'PASS native ooRexx dev9 script authority pinning'
