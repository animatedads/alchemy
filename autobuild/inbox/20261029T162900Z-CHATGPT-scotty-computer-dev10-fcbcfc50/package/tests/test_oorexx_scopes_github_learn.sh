#!/usr/bin/env bash
# End-to-end native ooRexx: named search scopes, GitHub SSH alias resolution,
# two-stage learned-intention attestation and staged Git mutation.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/inbound" "$T/dependencies" "$T/irrelevant" "$T/config" "$T/bin" "$T/repo"
export HOME="$T" XDG_CONFIG_HOME="$T/config"
export PATH="$T/bin:$PATH"
cat > "$T/bin/ssh" <<'SSH'
#!/usr/bin/env bash
[[ $1 == -G ]] || exit 91
case "${2:-}" in
  gh-project-a) printf '%s\n' 'hostname github.com' 'user git' 'identityfile ~/.ssh/project-a-deploy' 'identitiesonly yes' 'port 22';;
  *) exit 92;;
esac
SSH
chmod +x "$T/bin/ssh"
run() { "$REXX_BIN" "$HERE/Computer" "$*"; }
printf 'download\n' > "$T/inbound/received.txt"
printf '::class Crypto\n' > "$T/dependencies/Crypto.cls"
printf 'irrelevant!\n' > "$T/irrelevant/Crypto_newest.cls"
python3 - "$T/dependencies" <<'PY'
import sys,zipfile
with zipfile.ZipFile(sys.argv[1]+'/crypto_v0.8.3.zip','w') as f:
    f.writestr('lib/Crypto.cls','::class Crypto\n')
PY
run "add $T/inbound to my find file locations as inboundfiles" | grep -E '^ADDED search_scope=inboundfiles' > /dev/null
run "add $T/dependencies to my find file locations as dependencies" | grep -E '^ADDED search_scope=dependencies' > /dev/null
scopes=$(run '--json search scopes')
python3 - "$scopes" "$T" <<'PY'
import json,sys
j=json.loads(sys.argv[1]); base=sys.argv[2]
a={e['name']:e['directories'] for e in j['scopes']}
assert a['inboundfiles']==[base+'/inbound']
assert a['dependencies']==[base+'/dependencies']
PY
recent=$(run '--json find new files in last 30 minutes in inboundfiles')
deps=$(run '--json find dependency rexx crypto in dependencies')
python3 - "$recent" "$deps" <<'PY'
import json,sys
r=json.loads(sys.argv[1]); d=json.loads(sys.argv[2])
assert r['scope']=='inboundfiles' and any(x['path'].endswith('received.txt') for x in r['candidates'])
assert d['scope']=='dependencies' and any(x.get('archive_member')=='lib/Crypto.cls' for x in d['candidates'])
assert all('irrelevant' not in x['path'] for x in d['candidates'])
assert all('reason' in x and 'modified_utc' in x and 'size_bytes' in x and 'hash_status' in x for x in d['candidates'])
assert d['candidates']==sorted(d['candidates'],key=lambda x:(-x['modified_epoch_ns'],x['path'],x.get('archive_member','')))
PY
set +e
invalid=$(run 'find dependency rexx crypto in unknownscope' 2>&1); invalid_rc=$?
set -e
[[ $invalid_rc == 3 && "$invalid" == *'Unknown search scope'* ]]
# Project-specific configured SSH alias must be honoured without -i or rewriting the URL.
git init -q "$T/repo"
git -C "$T/repo" config user.name 'Computer Test'
git -C "$T/repo" config user.email 'computer@test.invalid'
printf 'first\n' > "$T/repo/readme.txt"
git -C "$T/repo" add -- readme.txt
git -C "$T/repo" commit -qm initial
git -C "$T/repo" remote add origin 'git@gh-project-a:example/repository.git'
profile=$(run "github inspect $T/repo")
[[ "$profile" == *'ALIAS=gh-project-a RESOLVED_HOST=github.com'* ]]
[[ "$profile" == *'identityfile=~/.ssh/project-a-deploy'* ]]
[[ "$profile" == *'REMOTE_URL=git@gh-project-a:example/repository.git'* ]]
fetch=$(COMPUTER_DRY_RUN=1 run "github fetch $T/repo")
[[ "$fetch" == *"git -C $T/repo fetch --no-tags origin"* ]]
[[ "$fetch" != *'COMMAND=git -i'* ]]
pull=$(COMPUTER_DRY_RUN=1 run "github pull $T/repo")
[[ "$pull" == *"git -C $T/repo pull --ff-only origin"* ]]
# Stage+confirm invokes local git; no network credentials involved.
printf 'second\n' > "$T/repo/second.txt"
set +e
stage=$(run "github stage $T/repo file second.txt"); stage_rc=$?
set -e
[[ $stage_rc == 3 && "$stage" == *'NOT EXECUTED'* ]]
stagetoken=$(printf '%s\n' "$stage" | sed -n 's/^Computer confirm //p')
[[ ${#stagetoken} == 32 ]]
run "confirm $stagetoken" | grep -E 'OK github_stage' > /dev/null
git -C "$T/repo" diff --cached --name-only | grep -Ex second.txt > /dev/null
set +e
commit=$(run "github commit $T/repo message 'second commit'"); commit_rc=$?
set -e
[[ $commit_rc == 3 && "$commit" == *'Git commit hooks'* ]]
committoken=$(printf '%s\n' "$commit" | sed -n 's/^Computer confirm //p')
run "confirm $committoken" | grep -E 'OK github_commit' > /dev/null
[[ $(git -C "$T/repo" log -1 --format=%s) == 'second commit' ]]
# Learning: review the actual shell-rendered Computer command and then activate once.
set +e
review=$(run 'learn locatecrypto as "find dependency rexx crypto in dependencies"'); review_rc=$?
set -e
[[ $review_rc == 3 && "$review" == *'POSITIONAL/OPTIONS:'* ]]
reviewtoken=$(printf '%s\n' "$review" | sed -nE 's/^REVIEW: Computer .*learn review ([A-Za-z0-9_-]{32}).*/\1/p')
[[ ${#reviewtoken} == 32 ]]
rendered="Computer 'find dependency rexx crypto in dependencies'"
set +e
attestation=$(run "learn review $reviewtoken $rendered"); attest_rc=$?
set -e
[[ $attest_rc == 3 && "$attestation" == *'STRUCTURE_ATTESTED'* ]]
activation=$(printf '%s\n' "$attestation" | sed -n 's/^NOT ACTIVATED until: Computer confirm //p')
[[ ${#activation} == 32 ]]
run "confirm $activation" | grep -E 'ACTIVATED named intention=locatecrypto' > /dev/null
run 'do locatecrypto' | grep -E 'crypto_v0.8.3.zip' > /dev/null
set +e
replay=$(run "confirm $activation" 2>&1); replay_rc=$?
set -e
[[ $replay_rc == 4 && "$replay" == *'used or expired'* ]]
echo 'PASS ooRexx scoped search/GitHub/learn integration'
