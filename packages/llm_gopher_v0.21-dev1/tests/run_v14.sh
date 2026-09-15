#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# setup help is shell-native and side-effect free
LLM_GOPHER_ENV="$TMP/never-created" "$ROOT/gopher" setup -h > "$TMP/setup-help"
test ! -e "$TMP/never-created"
grep -q 'LLM GOPHER SETUP / BOOTSTRAP' "$TMP/setup-help"
grep -q 'no downloads' "$TMP/setup-help"

# root help without a proven runtime must direct the caller to setup
PATH=/usr/bin:/bin LLM_GOPHER_ENV= "$ROOT/gopher" -h > "$TMP/pre-help"
grep -q 'gopher setup' "$TMP/pre-help"

# If the caller provides a prepared runtime, root help must publish live scope.
# The outer qualification harness supplies LLM_GOPHER_TEST_REXX when testing
# against the exact ooRexx runtime.
if [ -n "${LLM_GOPHER_TEST_REXX:-}" ] && [ -x "$LLM_GOPHER_TEST_REXX" ]; then
  mkdir -p "$TMP/env/runtime/oorexx/usr/local/bin"
  ln -s "$LLM_GOPHER_TEST_REXX" "$TMP/env/runtime/oorexx/usr/local/bin/rexx"
  LLM_GOPHER_ENV="$TMP/env" "$ROOT/gopher" -h > "$TMP/ready-help"
  grep -q 'YOU SHOULD BE USING THIS' "$TMP/ready-help"
  grep -q 'Relevant operational pages:' "$TMP/ready-help"
  grep -q 'Published service scope:' "$TMP/ready-help"
  grep -q 'source.oorexx.examine' "$TMP/ready-help"
  grep -q 'package.stage.check' "$TMP/ready-help"
fi

# Dynamic help command itself is generated from loaded sphere objects.
"$ROOT/gopher" --profile oorexx help oorexx > "$TMP/help.json"
grep -q '"operation_status"' "$TMP/help.json"
grep -q '"capabilities"' "$TMP/help.json"
grep -q '"articles"' "$TMP/help.json"

echo "PASS ALL LLM GOPHER v0.14 SELF-DOCUMENTATION TESTS"
