#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${GOPHER_ROOT:?set GOPHER_ROOT to extracted llm_gopher_v0.21-dev1 root}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LLM_GOPHER_ENV="$TMP/env"
python3 - "$ROOT" "$TMP/sphere.zip" <<'PY2'
import sys,zipfile,pathlib
r=pathlib.Path(sys.argv[1]); out=sys.argv[2]
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(r.rglob('*')):
        if p.is_file() and p.name != 'MANIFEST.sha256': z.write(p,(r.name+'/'+p.relative_to(r).as_posix()))
PY2
"$GOPHER_ROOT/gopher" sphere load s370mvs --override "$TMP/sphere.zip" > "$TMP/load.json"
grep -q '"class": "ACTIVATED"' "$TMP/load.json"
grep -q '"version": "0.3-dev1"' "$TMP/load.json"
"$GOPHER_ROOT/gopher" --profile s370mvs context s370mvs --full > "$TMP/context.json"
grep -q '"id": "s370.project-evidence"' "$TMP/context.json"
check_lookup() { field=$1; value=$2; needle=$3; out=$4; "$GOPHER_ROOT/gopher" --profile s370mvs lookup "$field=$value" --sphere s370mvs > "$TMP/$out.json"; grep -q '"match_kind": "EXACT_FIELD"' "$TMP/$out.json"; grep -q "$needle" "$TMP/$out.json"; }
check_lookup opcode 5D 'specification exception before storage operand fetch' div
check_lookup opcode D1 'D10004E705D1' mvn
check_lookup opcode 02 'sealed Safety22' op02
check_lookup opcode 70 '0/2/4/6' op70
check_lookup checkpoint safety21 'SEALED_CHECKPOINT' s21
check_lookup checkpoint safety22 'SEALED_CHECKPOINT' s22
check_lookup checkpoint safety23 'SEALED_CHECKPOINT' s23
check_lookup opcode 44 '70E005C84780' ex44
"$GOPHER_ROOT/gopher" --profile s370mvs search 'use arg parse arg object identity' --sphere s370mvs > "$TMP/usearg.json"
grep -q 'object identity is preserved' "$TMP/usearg.json"
mkdir "$TMP/conflict"; cat > "$TMP/conflict/00.json" <<'JSON2'
{"kind":"sphere","id":"s370mvs","version":"999","title":"conflict"}
JSON2
if "$GOPHER_ROOT/gopher" merge "$GOPHER_ROOT/packs/core" "$ROOT/packs/s370mvs" "$TMP/conflict" > "$TMP/conflict.json"; then echo 'expected conflicting semantic pack merge to fail' >&2; exit 1; fi
grep -q '"class": "CONFLICT"' "$TMP/conflict.json"
echo 'PASS ALL s370mvs SPHERE v0.3-dev1 TESTS'
