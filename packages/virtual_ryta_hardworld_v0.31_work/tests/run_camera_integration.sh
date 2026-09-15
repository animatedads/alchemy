#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${CAMERA_CORE_DIR:-}" ]]; then
  echo "CAMERA_CORE_DIR must point to the directory containing CameraCore.cls" >&2
  exit 2
fi
if [[ ! -f "$CAMERA_CORE_DIR/CameraCore.cls" ]]; then
  echo "CameraCore.cls not found under CAMERA_CORE_DIR=$CAMERA_CORE_DIR" >&2
  exit 2
fi
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
mkdir -p "$TMPDIR_TEST/tests"
ln -s "$ROOT/algorithm" "$TMPDIR_TEST/algorithm"
ln -s "$ROOT/integration" "$TMPDIR_TEST/integration"
ln -s "$CAMERA_CORE_DIR/CameraCore.cls" "$TMPDIR_TEST/CameraCore.cls"
cp "$ROOT/tests/test_algorithm_relation_camera_integration.rex" "$TMPDIR_TEST/tests/"
cd "$TMPDIR_TEST/tests"
rexx test_algorithm_relation_camera_integration.rex
