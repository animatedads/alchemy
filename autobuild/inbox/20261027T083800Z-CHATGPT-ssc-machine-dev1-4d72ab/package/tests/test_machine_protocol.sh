#!/usr/bin/env bash
set -euo pipefail
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
REXX="${REXX:-rexx}"
command -v "$REXX" >/dev/null 2>&1 || { echo "SKIP test_machine_protocol: rexx unavailable"; exit 77; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SRC="$TMP/src"; REPO="$TMP/repo"
mkdir -p "$SRC"
cat > "$SRC/Foo.cls" <<'SRC'
::class Foo public
::constant API_VERSION "1"
::attribute value get
::method run
  return 1
SRC
(
  cd "$ROOT/vendor/oorexx_semantic_source_control_v0.2.3"
  "$REXX" bin/osc.rex baseline "$SRC" --repo "$REPO" --component Demo --level 1 >/dev/null
)
check_json() { python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["schema"]=="semantic.source.control.machine/0.1"; print(x["operation_status"])'; }
"$ROOT/bin/ssc-machine" status Demo --repo "$REPO" | check_json | grep -q FOUND
"$ROOT/bin/ssc-machine" identify Demo Demo.Foo.run --repo "$REPO" | check_json | grep -Eq 'FOUND|AMBIGUOUS'
"$ROOT/bin/ssc-machine" compare Demo "$SRC" --repo "$REPO" | check_json | grep -q UNCHANGED
"$ROOT/bin/ssc-machine" impact Demo "$SRC" --repo "$REPO" --against "$SRC" | check_json | grep -q UNCHANGED
"$ROOT/bin/ssc-machine" source Demo Demo.Foo.run --repo "$REPO" | check_json | grep -q FOUND
"$ROOT/bin/ssc-machine" proposals --repo "$REPO" | check_json | grep -q FOUND
"$ROOT/bin/ssc-machine" identify Demo Demo.DoesNotExist --repo "$REPO" | check_json | grep -q NOT_FOUND
echo "PASS test_machine_protocol"
