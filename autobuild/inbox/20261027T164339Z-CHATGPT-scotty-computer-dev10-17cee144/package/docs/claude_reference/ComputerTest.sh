#!/bin/bash
# ComputerTest.sh - self-scoring test for the IntentionService-backed ./Computer.
# Run from the directory holding Computer, Computer.rex and ComputerIntentions.cls:
#   bash ComputerTest.sh
# Uses a throwaway HOME. Architecture: Tom Dyer. Coding: Claude Sonnet 5.5. UNTESTED.

export HOME
HOME=$(mktemp -d)
WORK=$(mktemp -d)
mkdir -p "$HOME/Downloads/current" "$WORK/src"
echo "hello needle" > "$HOME/Downloads/notes.txt"
echo "class crypto" > "$WORK/src/crypto.cls"
sleep 1
echo "class crypto v2" > "$HOME/Downloads/current/crypto.cls"

# stub sshnode.sh: echoes its arguments so we can verify what Computer would run
cat > "$WORK/sshnode.sh" <<'STUB'
#!/bin/sh
node=x
case "$node" in
  ed209a) user=opc;;
  ed209b) user=opc;;
  ed209c) user=azureuser;;
  ed209d) user=ec2-user;;
  *) echo "Unknown node" >&2;;
esac
echo "STUB sshnode args: $*"
STUB
chmod +x "$WORK/sshnode.sh"
export COMPUTER_SSHNODE="$WORK/sshnode.sh"
touch "$HOME/Downloads/MyBigZip.zip"

pass=0
fail=0
LASTOUT=""

# check <label> <expected-exit> <expected-text> <command words...>
check() {
  label="$1"; wantrc="$2"; want="$3"; shift 3
  LASTOUT=$(./Computer "$*" 2>&1)
  rc=$?
  if [ "$rc" = "$wantrc" ] && printf '%s' "$LASTOUT" | grep -qF -- "$want"; then
    pass=$((pass + 1))
    echo "PASS $label"
  else
    fail=$((fail + 1))
    echo "FAIL $label (rc=$rc, wanted rc=$wantrc and text: $want)"
    printf '%s\n' "$LASTOUT" | sed 's/^/     /'
  fi
}

check "add find location"           0 "OK intent=add-find-location changed=added" add "$HOME/Downloads" to my find file locations
check "add is idempotent"           0 "already registered"                         add "$HOME/Downloads" to my find file locations
check "add keeps path case"         0 "added $HOME/Downloads/current"              add "$HOME/Downloads/current" to my find file locations
check "add tilde path"              0 "already registered"                         add ~/Downloads to my find file locations
check "add temp dir"                0 "OK intent=add-temp-dir"                     add /tmp to my permitted temporary file directory
check "add missing dir refused"     1 "directory does not exist"                   add /no/such/dir to my find file locations
check "add relative path refused"   1 "path must be absolute"                      add Downloads to my find file locations
check "add shell metachar refused"  1 "forbidden character"                        add '/tmp/a;b' to my find file locations
check "add with no path needs one"  4 "NEEDS intent=ADD_FIND_LOCATION"             add to my find file locations
check "recent files"                0 "OK intent=find-recent-files"                find files received in my find files location in the past 30 minutes
check "recent without a number"     4 "NEEDS intent=FIND_RECENT_FILES"             find files received in my find files location in the past lots minutes
check "which file has"              0 "notes.txt"                                  which file has needle
check "latest copy"                 0 "LATEST"                                     find the latest copy of Crypto rexx class
check "latest is the newest"        0 "$HOME/Downloads/current/crypto.cls"         find the latest copy of Crypto rexx class
check "rexxpath"                    0 "OK intent=set-up-rexxpath"                  set up the rexxpath
check "login prints the command"    0 "sshnode.sh ed209b"                          log me into ED209B
check "login refuses unknown node"  1 "unknown node ed209f"                        log me into ed209f
check "unknown intent"              1 "VALID INTENTS"                              make me a sandwich
check "help"                        0 "VALID INTENTS"                              help

check "free space local"            0 "Filesystem"                                 check free space
check "free memory local"           0 "Mem:"                                       check free memory
check "free space on node"          0 "ed209a df"                                    check free space on ed209a
check "free memory, node lowercased" 0 "ed209d free"                                  check free memory on ED209D
check "computer prefix tolerated"   0 "Filesystem"                                 computer check free space
check "dangling on needs a node"    4 "NEEDS intent=CHECK_FREE_SPACE"              check free space on
check "unknown node ed209f refused" 1 "sshnode.sh knows: ed209a ed209b ed209c ed209d" check free space on ed209f
check "unknown alias ed209z refused" 1 "unknown node ed209z"                       check free space on ed209z
check "job id reaches sshnode.log"  0 "--job-id computer-check-free-space-ed209a-" check free space on ed209a
check "bad node name refused"       1 "invalid node name"                          check free space on 'bad;node'
OUT=$(COMPUTER_SSHNODE=/nonexistent ./Computer "check free space on ed209a" 2>&1); RC=$?
if [ "$RC" = 1 ] && printf '%s' "$OUT" | grep -qF "sshnode.sh not found"; then pass=$((pass + 1)); echo "PASS missing sshnode.sh reported"; else fail=$((fail + 1)); echo "FAIL missing sshnode.sh reported (rc=$RC)"; printf '%s\n' "$OUT" | sed 's/^/     /'; fi
check "deploy without node needs one" 4 "NEEDS intent=DEPLOY_ZIPFILE"             deploy zipfile MyBigZip.zip
check "deploy shows what it will do" 3 "NODE=ed209b"                      deploy zipfile MyBigZip.zip to ed209b
TOKEN=$(printf '%s\n' "$LASTOUT" | sed -n 's/^Computer confirm \([0-9]*\)$/\1/p')
check "deploy transfers the zip"    0 "OK intent=deploy-zipfile changed=transferred $HOME/Downloads/MyBigZip.zip to ed209b:MyBigZip.zip" confirm "$TOKEN"
check "deploy parks missing zip"    3 "NOT EXECUTED"                               deploy zipfile Nope.zip to ed209b
TOKEN=$(printf '%s\n' "$LASTOUT" | sed -n 's/^Computer confirm \([0-9]*\)$/\1/p')
check "deploy missing zip fails"    1 "not found in the registered"                confirm "$TOKEN"

# Destructive intent: must NOT execute on the first call, and the token works once.
check "firewall needs confirm"      3 "NOT EXECUTED"                               fix the firewall on ed209c
TOKEN=$(printf '%s\n' "$LASTOUT" | sed -n 's/^Computer confirm \([0-9]*\)$/\1/p')
if [ -z "$TOKEN" ]; then
  fail=$((fail + 1)); echo "FAIL could not read a confirm token"
else
  check "confirm runs it"           1 "not implemented yet"                        confirm "$TOKEN"
  check "token is single use"       1 "unknown, used or malformed token"           confirm "$TOKEN"
fi
check "bad token refused"           1 "malformed token"                            confirm ../../etc/passwd

echo "SCORE: $pass passed, $fail failed"
[ "$fail" = 0 ]
