#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
W="$TMP/work"

"$ROOT/gopher" sphere edit create fish-test --path "$W" --title "FISH Test Sphere" --purpose "Sphere editor regression." > "$TMP/create"
grep -q '"class": "CREATED"' "$TMP/create"

"$ROOT/gopher" sphere edit template article --sphere fish-test --id ops.fish --title "Provenance panic" --out "$TMP/article.json" > "$TMP/template"
grep -q '"kind": "article"' "$TMP/template"

"${LLM_GOPHER_PYTHON:-python3}" - "$TMP/article.json" <<'PY'
import json,sys
p=sys.argv[1]
o=json.load(open(p))
o["summary"]="Structured provenance survives explanatory prose panic."
o["authority"]="project-doctrine"
json.dump(o,open(p,"w"),indent=2);open(p,"a").write("\n")
PY
"$ROOT/gopher" sphere edit put article --sphere fish-test --path "$W" --from "$TMP/article.json" > "$TMP/put"
grep -q '"class": "CREATED"' "$TMP/put"
SHA=$("${LLM_GOPHER_PYTHON:-python3}" - "$TMP/put" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))["result"]["after_sha256"])
PY
)

"$ROOT/gopher" sphere edit template corpus --sphere fish-test --id fish.lessons --title "Lessons" --out "$TMP/corpus.json" > /dev/null
"$ROOT/gopher" sphere edit put corpus --sphere fish-test --path "$W" --from "$TMP/corpus.json" > /dev/null
printf '%s\n' '{"topic":"FISH","rule":"Structured provenance wins over panicked prose."}' > "$TMP/record.json"
"$ROOT/gopher" sphere edit record-put fish.lessons --sphere fish-test --path "$W" --from "$TMP/record.json" --key topic --value FISH > "$TMP/record-put"
grep -q '"class": "CREATED"' "$TMP/record-put"

"$ROOT/gopher" sphere edit evidence article ops.fish --sphere fish-test --path "$W" \
  --artifact runtime_registry_v0.14.zip \
  --sha256 1111111111111111111111111111111111111111111111111111111111111111 \
  --member README.md --line-start 38 --line-end 45 \
  --claim "WLU integration evidence" \
  --note "la la la la la la la ... oh I mean line 38-45" \
  --expected-sha256 "$SHA" > "$TMP/fish"
grep -q '"class": "UPDATED"' "$TMP/fish"
grep -q 'la la la la' "$TMP/fish"

# Prose panic must not damage machine provenance validation.
"$ROOT/gopher" sphere edit validate fish-test --path "$W" > "$TMP/valid"
grep -q '"class": "VALID"' "$TMP/valid"
grep -q '"problem_count": 0' "$TMP/valid"

# Stale-source fencing.
if "$ROOT/gopher" sphere edit put article --sphere fish-test --path "$W" --from "$TMP/article.json" \
     --expected-sha256 0000000000000000000000000000000000000000000000000000000000000000 > "$TMP/stale"; then
  echo "expected stale source rejection" >&2
  exit 1
fi
grep -q '"class": "STALE_SOURCE"' "$TMP/stale"

"$ROOT/gopher" sphere edit changelog-add --path "$W" --version 0.1 --text "Added FISH regression." > "$TMP/changelog"
grep -q '"class": "UPDATED"' "$TMP/changelog"
"$ROOT/gopher" sphere edit changelog-add --path "$W" --version 0.1 --text "Added FISH regression." > "$TMP/changelog2"
grep -q '"class": "EXISTS"' "$TMP/changelog2"

# Complete lint prerequisites and start page.
"${LLM_GOPHER_PYTHON:-python3}" - "$W/packs/fish-test/00-sphere.json" <<'PY'
import json,sys
p=sys.argv[1];o=json.load(open(p));o["start_here"]=["ops.fish"];json.dump(o,open(p,"w"),indent=2);open(p,"a").write("\n")
PY
printf '#!/bin/sh\nexit 0\n' > "$W/tests/run.sh"
chmod +x "$W/tests/run.sh"
printf '%s\n' 'PASS FISH provenance regression' > "$W/qualification/QUALIFICATION.txt"

"$ROOT/gopher" sphere edit lint fish-test --path "$W" > "$TMP/lint"
grep -q '"class": "CLEAN"' "$TMP/lint"
grep -q '"warning_count": 0' "$TMP/lint"

"$ROOT/gopher" sphere edit package fish-test --path "$W" --out "$TMP/fish-test.zip" --require-clean-lint > "$TMP/package"
grep -q '"class": "PACKAGED"' "$TMP/package"
"${LLM_GOPHER_PYTHON:-python3}" - "$TMP/fish-test.zip" <<'PY'
import sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None
    names=z.namelist()
    assert any(x.endswith('/packs/fish-test/articles/ops.fish.json') for x in names)
    assert any(x.endswith('/qualification/MANIFEST.sha256') for x in names)
PY

"$ROOT/gopher" --profile sphere-authoring context sphere-authoring --full > "$TMP/context"
grep -q '"sphere.editor.template"' "$TMP/context"
grep -q '"sphere.editor.corpus.record.put"' "$TMP/context"
grep -q '"sphere.editor.evidence.attach"' "$TMP/context"

"$ROOT/gopher" --profile sphere-authoring search FISH --sphere sphere-authoring > "$TMP/search"
grep -q '"class": "FOUND"' "$TMP/search"

echo "PASS ALL LLM GOPHER v0.19 SPHERE EDITOR TESTS"
