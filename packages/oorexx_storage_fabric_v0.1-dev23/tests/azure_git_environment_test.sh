#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"

# Full live provider qualification.  Credentials are consumed from environment
# only and are never written into Storage Fabric state, package files or Git URLs.
: "${STORAGE_GIT_PASSWORD:?set STORAGE_GIT_PASSWORD to the test Azure DevOps PAT/password}"
STORAGE_GIT_USER=${STORAGE_GIT_USER:-animatedadscy}
STORAGE_GIT_REPO_URL=${STORAGE_GIT_REPO_URL:-https://animatedadscy@dev.azure.com/animatedadscy/storage_fabric/_git/storage_fabric}
STORAGE_GIT_BRANCH=${STORAGE_GIT_BRANCH:-storage-fabric-live-qualification}
REXX_BIN=${REXX_BIN:-rexx}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/storage-git-azure.XXXXXX")
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
cat >"$TMP/askpass.sh" <<'ASK'
#!/bin/sh
case "$1" in
  *sername*) printf '%s\n' "$STORAGE_GIT_USER" ;;
  *assword*) printf '%s\n' "$STORAGE_GIT_PASSWORD" ;;
  *) exit 1 ;;
esac
ASK
chmod 700 "$TMP/askpass.sh"
export GIT_ASKPASS="$TMP/askpass.sh"
export GIT_TERMINAL_PROMPT=0
export STORAGE_GIT_USER STORAGE_GIT_PASSWORD

# Prove transport/auth before invoking Storage semantics.
git ls-remote "$STORAGE_GIT_REPO_URL" >/dev/null

python3 - "$TMP/source.bin" <<'PY'
import os,sys,time
p=sys.argv[1]
# Crosses the test provider's 64 KiB chunk boundary many times and contains
# binary data.  A live qualification should verify bytes, not just text files.
data=(bytes(range(256))*4096) + b'\x00AZURE-STORAGE-FABRIC-LIVE\xff\n'
with open(p,'wb') as f: f.write(data)
PY
DIGEST=$(sha256sum "$TMP/source.bin" | awk '{print $1}')
export REXX_PATH="$HERE/src${REXX_PATH:+:$REXX_PATH}"

# The ooRexx regression uses its standard branch name.  Give it an isolated
# remote URL by cloning an Azure-backed working repository and pointing the test
# at the same service.  Branch creation/update is deliberately non-destructive.
"$REXX_BIN" "$HERE/tests/test_git_provider.rex" \
  "$STORAGE_GIT_REPO_URL" "$TMP/work" "$TMP/source.bin" "$DIGEST" "$TMP/restored.bin" "$STORAGE_GIT_BRANCH"
cmp "$TMP/source.bin" "$TMP/restored.bin"

echo "PASS Storage Git provider Azure DevOps live store/fetch/verify"
