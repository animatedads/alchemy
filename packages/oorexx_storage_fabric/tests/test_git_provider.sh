#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/storage-git-local.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

git init --bare -q --initial-branch=main "$TMP/remote.git"
python3 - "$TMP/source.bin" <<'PY'
import os,sys
p=sys.argv[1]
with open(p,'wb') as f:
    f.write(bytes(range(256))*1400)
    f.write(b'\x00StorageFabric\xffGit\n')
PY
DIGEST=$(sha256sum "$TMP/source.bin" | awk '{print $1}')
export REXX_PATH="$HERE/src${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$HERE/tests/test_git_provider.rex" \
  "$TMP/remote.git" "$TMP/work" "$TMP/source.bin" "$DIGEST" "$TMP/restored.bin" "storage-fabric-test"
cmp "$TMP/source.bin" "$TMP/restored.bin"
git --git-dir="$TMP/remote.git" show-ref --verify refs/heads/storage-fabric-test >/dev/null
echo "PASS Storage Git provider local bare-repository integration"
