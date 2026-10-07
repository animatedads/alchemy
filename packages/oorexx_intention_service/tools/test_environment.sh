#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_REVISION="13196"
DEB_PATH="${OOREXX_DEB:-}"

if [[ -n "$DEB_PATH" ]]; then
  if [[ ! -f "$DEB_PATH" ]]; then
    echo "FAIL: OOREXX_DEB does not exist: $DEB_PATH" >&2
    exit 2
  fi
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  dpkg-deb -x "$DEB_PATH" "$WORK/root"
  REXX_BIN="$(find "$WORK/root" -type f -name rexx -perm -u+x | head -1)"
  if [[ -z "$REXX_BIN" ]]; then
    echo "FAIL: rexx binary not found inside $DEB_PATH" >&2
    exit 2
  fi
  LIBDIR="$(dirname "$(find "$WORK/root" -type f \( -name 'librexx.so*' -o -name 'librexxapi.so*' \) | head -1)")"
  export LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}"
else
  REXX_BIN="$(command -v rexx || true)"
  if [[ -z "$REXX_BIN" ]]; then
    echo "FAIL: rexx not found. Set OOREXX_DEB=/path/to/oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb" >&2
    exit 2
  fi
fi

VERSION_TEXT="$($REXX_BIN -v 2>&1 || true)"
echo "$VERSION_TEXT"
if ! grep -q "$EXPECTED_REVISION" <<<"$VERSION_TEXT"; then
  echo "FAIL: expected ooRexx revision $EXPECTED_REVISION" >&2
  exit 3
fi

export REXX_PATH="$ROOT/src:$ROOT/src/nlp${REXX_PATH:+:$REXX_PATH}"

failed=0
for test_file in "$ROOT"/tests/*.rex; do
  echo "==> $(basename "$test_file")"
  if ! "$REXX_BIN" "$test_file"; then
    failed=1
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "FAIL: intention service environment qualification" >&2
  exit 1
fi

echo "PASS: intention service environment qualification on ooRexx revision $EXPECTED_REVISION"

