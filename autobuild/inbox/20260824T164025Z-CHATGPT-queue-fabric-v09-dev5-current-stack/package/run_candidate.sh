#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-all}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
cleanup(){ rm -rf "$WORK"; }
trap cleanup EXIT
ARCHIVE="$WORK/candidate.tar.xz"
cat "$HERE"/candidate.b64.* | base64 -d > "$ARCHIVE"
python3 - "$ARCHIVE" "$WORK" <<'PY'
import sys, tarfile
tar_path, out = sys.argv[1:]
with tarfile.open(tar_path, 'r:xz') as t:
    t.extractall(out)
PY
cd "$WORK"
export CRYPTO_SRC="$WORK/testdeps/oorexx_crypto_v0.1/src"
export NOSQL_SRC="$WORK/testdeps/nosqlserver_v0.77/src"
export RUNTIME_REGISTRY_SRC="$WORK/testdeps/runtime_registry_v0.13/src"
export ALCHEMY_OBJECTS_SRC="$WORK/testdeps/alchemy_objects_v0.7/src"
export WLU_SRC="$WORK/testdeps/oorexx_work_load_units_v0.12/src"
export QF_V082_SRC="$WORK/testdeps/oorexx_queue_fabric_v0.8.2/src"
export REXX_PATH="$WORK/src:$CRYPTO_SRC:$NOSQL_SRC:$RUNTIME_REGISTRY_SRC:$ALCHEMY_OBJECTS_SRC:$WLU_SRC${REXX_PATH:+:$REXX_PATH}"
sha256sum -c MANIFEST.sha256
if [[ "$MODE" == "manifest" ]]; then
  exit 0
fi
bash run_tests.sh "$MODE"
