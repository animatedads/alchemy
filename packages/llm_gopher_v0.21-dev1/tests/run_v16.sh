#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${LLM_GOPHER_TEST_API_ROLLUP:?set LLM_GOPHER_TEST_API_ROLLUP to the ooRexx API roll-up}"
PY=${LLM_GOPHER_PYTHON:-python3}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LLM_GOPHER_ENV="$TMP/env"
mkdir -p "$LLM_GOPHER_ENV"

for S in maths kl10 s370mvs; do
  "$ROOT/gopher" sphere resolve "$S" --api-rollup "$LLM_GOPHER_TEST_API_ROLLUP" > "$TMP/$S.resolve"
  grep -q '"class": "FOUND"' "$TMP/$S.resolve"
  grep -q '"source_class": "delivered"' "$TMP/$S.resolve"
done
grep -q 'current/sphere/oorexx_maths_gopher_sphere_v0.1.zip' "$TMP/maths.resolve"
grep -q 'current/sphere/kl10_sphere_v0.1-dev1.zip' "$TMP/kl10.resolve"
grep -q 'current/sphere/s370mvs_sphere_v0.1-dev1.zip' "$TMP/s370mvs.resolve"

"$ROOT/gopher" sphere load s370mvs --api-rollup "$LLM_GOPHER_TEST_API_ROLLUP" > "$TMP/s370.load"
"$ROOT/gopher" --profile s370mvs lookup opcode=5D --sphere s370mvs > "$TMP/s370.lookup"
grep -q '"match_kind": "EXACT_FIELD"' "$TMP/s370.lookup"
grep -q '"mnemonic": "D"' "$TMP/s370.lookup"

# Build a deliberately improved local Maths dataset under an arbitrary filename.
OVDIR="$LLM_GOPHER_ENV/overrides/spheres"
mkdir -p "$OVDIR"
"$PY" - "$LLM_GOPHER_TEST_API_ROLLUP" "$OVDIR/local-research-copy.zip" <<'PY'
import sys,zipfile,io,json,tempfile,pathlib,shutil
outer_path,out_path=sys.argv[1:3]
with zipfile.ZipFile(outer_path) as outer:
    data=outer.read('current/sphere/oorexx_maths_gopher_sphere_v0.1.zip')
tmp=pathlib.Path(tempfile.mkdtemp())
try:
    with zipfile.ZipFile(io.BytesIO(data)) as z:z.extractall(tmp)
    p=tmp/'packs/maths/00-sphere-maths.json'
    o=json.loads(p.read_text());o['version']='0.2-local';o['title']='Maths LOCAL OVERRIDE';p.write_text(json.dumps(o,indent=2)+'\n')
    p=tmp/'profiles/maths.json'
    o=json.loads(p.read_text());o['version']='0.2-local';p.write_text(json.dumps(o,indent=2)+'\n')
    p=tmp/'packs/maths/10-corpus-maths.continuity.json'
    o=json.loads(p.read_text());o['records'].append({'topic':'override probe','rule':'LOCAL IMPROVED DATASET ACTIVE'});p.write_text(json.dumps(o,indent=2)+'\n')
    m=tmp/'qualification/MANIFEST_MATHS_SPHERE.sha256'
    if m.exists():m.unlink()
    with zipfile.ZipFile(out_path,'w',zipfile.ZIP_DEFLATED) as z:
        for f in sorted(tmp.rglob('*')):
            if f.is_file():z.write(f,f.relative_to(tmp).as_posix())
finally:
    shutil.rmtree(tmp)
PY

"$ROOT/gopher" sphere resolve maths --api-rollup "$LLM_GOPHER_TEST_API_ROLLUP" > "$TMP/local.resolve"
grep -q '"source_class": "local_override"' "$TMP/local.resolve"
grep -q '"version": "0.2-local"' "$TMP/local.resolve"
grep -q '"source_class": "delivered"' "$TMP/local.resolve"

"$ROOT/gopher" sphere load maths --api-rollup "$LLM_GOPHER_TEST_API_ROLLUP" > "$TMP/local.load"
"$ROOT/gopher" --profile maths lookup 'topic=override probe' --sphere maths > "$TMP/local.lookup"
grep -q 'LOCAL IMPROVED DATASET ACTIVE' "$TMP/local.lookup"

# Multiple implicit local candidates must fail closed.
cp "$OVDIR/local-research-copy.zip" "$OVDIR/another-copy.zip"
if "$ROOT/gopher" sphere resolve maths --api-rollup "$LLM_GOPHER_TEST_API_ROLLUP" > "$TMP/ambiguous"; then
  echo "expected ambiguous local override resolution to fail" >&2
  exit 1
fi
grep -q '"class": "AMBIGUOUS"' "$TMP/ambiguous"

# An explicit override resolves that ambiguity deterministically.
"$ROOT/gopher" sphere resolve maths --api-rollup "$LLM_GOPHER_TEST_API_ROLLUP" --override "$OVDIR/local-research-copy.zip" > "$TMP/explicit"
grep -q '"source_class": "explicit_override"' "$TMP/explicit"

echo "PASS ALL LLM GOPHER v0.16 SPHERE RETRIEVAL/OVERRIDE TESTS"
