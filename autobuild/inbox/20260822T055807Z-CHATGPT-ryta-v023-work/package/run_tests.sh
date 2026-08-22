#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-all}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ryta-v023-git-autobuild.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PAYLOAD="$WORK/ryta_v023_autobuild_payload.zip"
cat "$HERE"/payload/ryta_v023_payload.zip.b64.* | base64 -d > "$PAYLOAD"
EXPECTED_PAYLOAD="$(awk '$2 == "ryta_v023_autobuild_payload.zip" {print $1}' "$HERE/payload/SHA256")"
ACTUAL_PAYLOAD="$(sha256sum "$PAYLOAD" | awk '{print $1}')"
[[ "$ACTUAL_PAYLOAD" == "$EXPECTED_PAYLOAD" ]] || {
  echo "payload checksum mismatch" >&2
  echo "expected=$EXPECTED_PAYLOAD" >&2
  echo "actual=$ACTUAL_PAYLOAD" >&2
  exit 70
}

mkdir -p "$WORK/payload"
unzip -q "$PAYLOAD" -d "$WORK/payload"
(
  cd "$WORK/payload"
  tail -n +2 "$HERE/payload/SHA256" | sha256sum -c -
)

mkdir -p "$WORK/source_unpack" "$WORK/deps/camera_behaviour_oorexx_v0.34"
unzip -q "$WORK/payload/virtual_ryta_hardworld_v0.23_work.zip" -d "$WORK/source_unpack"
SRC="$WORK/source_unpack/virtual_ryta_hardworld_v0.23_work"
unzip -q "$WORK/payload/deps_zips/camera_behaviour_oorexx_v0.34.zip" -d "$WORK/deps/camera_behaviour_oorexx_v0.34"
unzip -q "$WORK/payload/deps_zips/structured_relation_plugin_v0.9.zip" -d "$WORK/deps"
unzip -q "$WORK/payload/deps_zips/legal_effect_v0.7.zip" -d "$WORK/deps"
unzip -q "$WORK/payload/deps_zips/runtime_registry_v0.11.zip" -d "$WORK/deps"
unzip -q "$WORK/payload/deps_zips/oorexx_queue_fabric_v0.8.1.zip" -d "$WORK/deps"
unzip -q "$WORK/payload/deps_zips/nosqlserver_v0.75.zip" -d "$WORK/deps"

export CAMERA_CORE_DIR="$WORK/deps/camera_behaviour_oorexx_v0.34"
export STRUCTURED_RELATION_ROOT="$WORK/deps/structured_relation_plugin_v0.9"
export LEGAL_EFFECT_ROOT="$WORK/deps/legal_effect_v0.7"
export RUNTIME_REGISTRY_ROOT="$WORK/deps/runtime_registry_v0.11"
export QUEUE_FABRIC_ROOT="$WORK/deps/oorexx_queue_fabric_v0.8.1"
export NOSQL_CLS="$WORK/deps/nosqlserver_v0.75/src/NoSQLServer.cls"

case "$MODE" in
  payload)
    echo "PAYLOAD SHA256: $ACTUAL_PAYLOAD"
    echo "SOURCE ZIP SHA256: $(sha256sum "$WORK/payload/virtual_ryta_hardworld_v0.23_work.zip" | awk '{print $1}')"
    ;;
  source-manifest)
    cd "$SRC"
    sha256sum -c MANIFEST.sha256
    ;;
  compile)
    command -v rexxc >/dev/null 2>&1 || { echo "rexxc not found" >&2; exit 127; }
    count=0
    while IFS= read -r -d '' f; do
      rexxc "$f" >/dev/null
      count=$((count + 1))
    done < <(find "$SRC" -type f -name '*.cls' -print0 | sort -z)
    echo "REXXC classes: $count PASS"
    ;;
  inherited)
    cd "$SRC/tests"
    exec ./run_all.sh
    ;;
  current-stack)
    exec "$SRC/tests/run_current_stack_rollup_v023.sh"
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    exit 64
    ;;
esac
