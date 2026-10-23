#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/project/src" "$TMP/project/rexx"
cat > "$TMP/project/src/RelationshipCaseService.cls" <<'EOF'
::class RelationshipCaseServiceBuild public
::method build
  return .true

::class RelationshipCaseServiceCanonical public
::method canonical
  return .true

::class RelationshipCaseService public
::method run
  return .true
EOF
printf '%s\n' '::class WrongLegacyCopy public' > "$TMP/project/rexx/RelationshipCaseService.cls"
${LLM_GOPHER_PYTHON:-python3} - "$TMP" <<'PY'
import sys,zipfile,pathlib
r=pathlib.Path(sys.argv[1])
with zipfile.ZipFile(r/'source.zip','w',zipfile.ZIP_DEFLATED) as z:
    for f in sorted((r/'project').rglob('*')):
        if f.is_file():z.write(f,f.relative_to(r).as_posix())
PY
"$ROOT/gopher" --profile oorexx examine source RelationshipCaseService.cls --in "$TMP/source.zip" --symbol RelationshipCaseService > "$TMP/exact"
grep -q '"member": "project/src/RelationshipCaseService.cls"' "$TMP/exact"
grep -q '"match_kind": "EXACT_DECLARATION"' "$TMP/exact"
grep -q '"line": 9' "$TMP/exact"

if "$ROOT/gopher" --profile oorexx examine source RelationshipCaseService.cls --in "$TMP/source.zip" --symbol RelationshipCase > "$TMP/no-fallback"; then
  :
fi
grep -q '"class": "NOT_FOUND"' "$TMP/no-fallback"
grep -q '"fallback_available": true' "$TMP/no-fallback"

"$ROOT/gopher" --profile oorexx examine source RelationshipCaseService.cls --in "$TMP/source.zip" --symbol RelationshipCase --symbol-fallback > "$TMP/fallback"
grep -q '"match_kind": "TEXT_FALLBACK"' "$TMP/fallback"
grep -q '"fallback_used": true' "$TMP/fallback"

cat > "$TMP/dup.cls" <<'EOF'
::class Foo public
::method a
  nop
::class Foo public
::method b
  nop
EOF
"$ROOT/gopher" --profile oorexx exec source.symbol.lookup path="$TMP/dup.cls" symbol=Foo language=oorexx > "$TMP/dup"
grep -q '"class": "AMBIGUOUS"' "$TMP/dup"

echo "PASS ALL LLM GOPHER v0.16 SOURCE CONTRACT TESTS"
