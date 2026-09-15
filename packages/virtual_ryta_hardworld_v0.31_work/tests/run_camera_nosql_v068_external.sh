#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAMERA_CORE_DIR="${CAMERA_CORE_DIR:-}"
NOSQL_CLS="${1:-}"
if [[ -z "$CAMERA_CORE_DIR" || ! -f "$CAMERA_CORE_DIR/CameraCore.cls" ]]; then
  echo "CAMERA_CORE_DIR must point to the directory containing CameraCore.cls" >&2
  exit 2
fi
if [[ -z "$NOSQL_CLS" || ! -f "$NOSQL_CLS" ]]; then
  echo "usage: CAMERA_CORE_DIR=/path/to/camera $0 /path/to/nosqlserver_v0.68/src/NoSQLServer.cls" >&2
  exit 2
fi
TMP="$(mktemp -d /tmp/virtual_ryta_camera_sql_v07.XXXXXX)"
DBROOT="$TMP/db"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT
mkdir -p "$TMP/tests" "$DBROOT/tables"
ln -s "$ROOT/algorithm" "$TMP/algorithm"
ln -s "$ROOT/integration" "$TMP/integration"
ln -s "$CAMERA_CORE_DIR/CameraCore.cls" "$TMP/CameraCore.cls"
ln -s "$(realpath "$NOSQL_CLS")" "$TMP/NoSQLServer.cls"
cp "$ROOT/tests/test_camera_nosql_v068_external_engine.rex" "$TMP/tests/"
cat > "$DBROOT/database.yaml" <<'YAML'
name: camera_algorithm_relation_v07
formatVersion: 1
tables: []
YAML
cd "$TMP/tests"
rexx test_camera_nosql_v068_external_engine.rex "$DBROOT"
