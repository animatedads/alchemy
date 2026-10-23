#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DEB=${LLM_GOPHER_TEST_OOREXX_DEB:?set LLM_GOPHER_TEST_OOREXX_DEB}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PATH_MIN="$TMP/bin"; mkdir -p "$PATH_MIN"
for x in sh sed find sort tail head rm mkdir chmod cat dpkg-deb ar tar python3 dirname; do p=$(command -v "$x" 2>/dev/null || true); [ -n "$p" ] && ln -s "$p" "$PATH_MIN/$x"; done
PATH="$PATH_MIN" "$ROOT/gopher" setup --no-launch --env "$TMP/env" --oorexx-deb "$DEB" > "$TMP/setup.json"
grep -q '"setup_status":"READY"' "$TMP/setup.json"
grep -q '"runtime_source":"deb-private"' "$TMP/setup.json"
test -x "$TMP/env/runtime/oorexx/usr/local/bin/rexx"
test -f "$TMP/env/state/setup.json"
PATH="$PATH_MIN" "$ROOT/gopher" setup --env "$TMP/env2" --oorexx-deb "$DEB" -- --profile oorexx context oorexx > "$TMP/launch.out"
grep -q '"setup_status":"READY"' "$TMP/launch.out"
grep -q '"class": "OPENED"' "$TMP/launch.out"
echo 'PASS ALL LLM GOPHER v0.13 SETUP/LAUNCH TESTS'
