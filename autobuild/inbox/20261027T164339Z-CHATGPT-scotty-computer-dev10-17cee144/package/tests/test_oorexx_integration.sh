#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/Downloads/current" "$T/config"
export HOME="$T" XDG_CONFIG_HOME="$T/config"
printf 'the needle for an actual ooRexx invocation\n' > "$T/Downloads/current/test.rex"
printf '::class Crypto\n' > "$T/Downloads/current/Crypto.cls"
run() { "$REXX_BIN" "$HERE/Computer" "$*"; }
run 'discover' | grep -F 'capabilities discovered' > /dev/null
run "add $T/Downloads to my find file locations" | grep -F ADDED > /dev/null
run "add $T/Downloads/current to my find file locations" | grep -F ADDED > /dev/null
run 'add /tmp to my permitted temporary file directory' | grep -F ADDED > /dev/null
run 'find files received in my find files location in the past 30 minutes' | grep -F test.rex > /dev/null
run 'which file has needle' | grep -F test.rex > /dev/null
run 'find the latest copy of Crypto rexx class' | grep -F 'LATEST_CANDIDATE' > /dev/null
run 'set up the rexxpath' | grep -F 'source' > /dev/null
COMPUTER_DRY_RUN=1 run 'log me into ED209B' | grep -F 'DRY_RUN sshnode.sh ed209b' > /dev/null
set +e
result=$(run 'fix the firewall on ed209f'); rc=$?
set -e
[[ "$rc" == 4 ]] && [[ "$result" == *'node absent'* ]]
# Claude-derived operational intents, tested via the real ooRexx dispatcher and a
# controlled SSH adapter that records argv; no external host contacted.
python3 - "$T/Downloads/current/transfer.zip" <<'PY_ZIP'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w') as z:
    z.writestr('src/example.cls', '::class Example\n')
PY_ZIP
cat > "$T/sshnode.sh" <<'SH_STUB'
#!/usr/bin/env bash
set -euo pipefail
case ed209b in
  ed209b) user=opc;;
esac
printf '%s\n' "$@" >> "$COMPUTER_TEST_SSH_ARGV"
echo "STUB: $*"
SH_STUB
chmod +x "$T/sshnode.sh"
export COMPUTER_SSHNODE="$T/sshnode.sh" COMPUTER_TEST_SSH_ARGV="$T/ssh-argv"
run 'check free space on ED209B' | grep -F 'OK check-free-space on ed209b' > /dev/null
python3 - "$T/ssh-argv" <<'PY_ARGV'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_text().splitlines()
assert args[0] == '--job-id' and args[1].startswith('computer-check-free-space-ed209b-')
assert args[2:] == ['ed209b', 'df', '-h'], args
PY_ARGV
set +e
missing=$(run 'check free space on' 2>&1); missing_rc=$?
set -e
[[ $missing_rc == 3 ]] && [[ "$missing" == *'Specify check free space'* ]]
set +e
preview=$(run 'deploy zipfile transfer.zip to ED209B'); preview_rc=$?
set -e
[[ $preview_rc == 3 ]] && [[ "$preview" == *'NOT EXECUTED'* ]]
token=$(printf '%s\n' "$preview" | sed -n 's/^Computer confirm //p')
[[ ${#token} == 32 ]]
[[ $(grep -c '^--transfer$' "$T/ssh-argv" || true) == 0 ]]
run "confirm $token" | grep -F 'OK transferred' > /dev/null
python3 - "$T/ssh-argv" "$T/Downloads/current/transfer.zip" <<'PY_TRANSFER'
import pathlib, sys
args = pathlib.Path(sys.argv[1]).read_text().splitlines()
assert '--transfer' in args
pos = args.index('--transfer')
assert args[pos + 1:] == ['ed209b', sys.argv[2]], args
PY_TRANSFER
set +e
reused=$(run "confirm $token" 2>&1); reused_rc=$?
set -e
[[ $reused_rc == 4 ]] && [[ "$reused" == *'used or expired'* ]]
set +e
result=$(COMPUTER_SSHNODE="$T/not-present" run 'log me into ED209B'); rc=$?
set -e
[[ "$rc" != 0 ]] && [[ "$result" == *'UNKNOWN:'* ]]
[[ -f "$T/config/scotty-computer/audit.jsonl" ]]
python3 - "$T/config/scotty-computer/audit.jsonl" <<'PY'
import json,sys
rows=[json.loads(s) for s in open(sys.argv[1])]
assert any(r['intent']=='FIREWALL_REPAIR' and r['exit_code']==4 for r in rows)
assert any(r['intent']=='SSH_LOGIN' and r['exit_code']==0 for r in rows)
assert all(set(r)=={'schema','at_utc','intent','request_sha256','exit_code'} for r in rows)
PY
# dev3 file integrity commands must travel through the real IntentionService READY gate.
python3 - "$T/Downloads/current" <<'PY_FIXTURES'
import hashlib, pathlib, sys
base = pathlib.Path(sys.argv[1])
(base / 'same.rex').write_bytes((base / 'test.rex').read_bytes())
digest = hashlib.sha256((base / 'test.rex').read_bytes()).hexdigest()
(base / 'SHA256SUMS').write_text(f'{digest}  test.rex\n{digest}  same.rex\n')
PY_FIXTURES
actual=$(run "--json sha256 \"$T/Downloads/current/test.rex\"")
python3 - "$actual" "$T/Downloads/current/test.rex" <<'PY_SHA'
import hashlib,json,sys
r=json.loads(sys.argv[1]); want=hashlib.sha256(open(sys.argv[2],'rb').read()).hexdigest()
assert r['rc']==0 and r['schema']=='scotty.computer.integrity/1' and r['digest']==want,r
PY_SHA
run "compare sha256 \"$T/Downloads/current/test.rex\" with \"$T/Downloads/current/same.rex\"" | grep -F 'MATCH operation=COMPARE_SHA256' > /dev/null
run "compare files \"$T/Downloads/current/test.rex\" with \"$T/Downloads/current/same.rex\"" | grep -F 'MATCH operation=COMPARE_FILES' > /dev/null
run "verify manifest \"$T/Downloads/current/SHA256SUMS\"" | grep -F 'MATCH operation=VERIFY_MANIFEST' > /dev/null
run "test zip \"$T/Downloads/current/transfer.zip\"" | grep -F 'OK operation=ZIP_TEST' > /dev/null
run "find sha256 $(sha256sum "$T/Downloads/current/test.rex" | cut -d' ' -f1)" | grep -F 'MATCH operation=FIND_SHA256' > /dev/null
run "inspect \"$T/Downloads/current/test.rex\"" | grep -F 'OK operation=INSPECT_FILE' > /dev/null
run instructions | grep -F 'Codex/automation operating contract' > /dev/null
printf 'altered\n' > "$T/Downloads/current/same.rex"
set +e
mismatch=$(run "--json compare files \"$T/Downloads/current/test.rex\" with \"$T/Downloads/current/same.rex\""); mismatch_rc=$?
set -e
[[ $mismatch_rc == 1 ]]
python3 - "$mismatch" <<'PY_MISMATCH'
import json,sys
r=json.loads(sys.argv[1]); assert r['status']=='MISMATCH' and r['rc']==1 and not r['identical'],r
PY_MISMATCH
set +e
invalid=$(run "--json verify sha256 bad \"$T/Downloads/current/test.rex\""); invalid_rc=$?
set -e
[[ $invalid_rc == 2 ]]
python3 - "$invalid" <<'PY_INVALID'
import json,sys
r=json.loads(sys.argv[1]); assert r['status']=='ERROR' and r['rc']==2,r
PY_INVALID
echo 'PASS ooRexx end-to-end Computer intents'
