#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

"$ROOT/gopher" --profile sphere-authoring context sphere-authoring --full > "$TMP/author"
grep -q '"sphere": "sphere-authoring"' "$TMP/author"
grep -q '"authoring-craft"' "$TMP/author"
grep -q '"sphere-internals"' "$TMP/author"
grep -q 'sphere-authoring.choose.valuable-is-not-more-code' "$TMP/author"
grep -q 'sphere-authoring.engine.no-engine-invasion' "$TMP/author"
grep -q 'sphere-authoring.qualify.qualify-version-deliver' "$TMP/author"

"$ROOT/gopher" --profile sphere-authoring menu sphere-authoring > "$TMP/menu"
grep -q '"sections"' "$TMP/menu"
grep -q '"references"' "$TMP/menu"

"$ROOT/gopher" --profile sphere-authoring search FISH --sphere sphere-authoring > "$TMP/fish"
grep -q '"class": "FOUND"' "$TMP/fish"

"$ROOT/gopher" --profile gemma-oorexx context gemma-oorexx --full > "$TMP/gemma"
grep -q '"gemma.current"' "$TMP/gemma"
grep -q '"gemma.generation-rules"' "$TMP/gemma"
grep -q '"gemma.handover"' "$TMP/gemma"
grep -q '"source.oorexx.examine"' "$TMP/gemma"

"$ROOT/gopher" --profile gemma-oorexx open gemma.current > "$TMP/current"
grep -q '"selected_proxy_score": 444' "$TMP/current"
grep -q '"substantial_programs": "0/6"' "$TMP/current"
grep -q '"status": "REJECT"' "$TMP/current"

"$ROOT/gopher" --profile gemma-oorexx search '0/6 substantial' --sphere gemma-oorexx > "$TMP/search"
grep -q '"class": "FOUND"' "$TMP/search"

# PROVENANCE_PANIC / FISH: legacy prose stays prose during canonical migration.
mkdir -p "$TMP/legacy/articles" "$TMP/legacy/corpus" "$TMP/legacy/qualification"
cat > "$TMP/legacy/00-manifest.json" <<'EOF'
{"id":"fish-legacy","name":"FISH Legacy","version":"0.1","description":"migration fixture","authority":"fixture/1"}
EOF
cat > "$TMP/legacy/01-access-policy.json" <<'EOF'
{"id":"fish-legacy-policy","default_action":"ALLOW","rules":[{"id":"R","action":"ALLOW","subjects":["*"],"resources":["*"]}]}
EOF
cat > "$TMP/legacy/articles/fish.json" <<'EOF'
{"id":"fish-article","title":"Provenance panic","summary":"A musical citation note.","evidence_note":"la la la la la la ... oh I mean line 38-45"}
EOF
printf '%s\n' '[{"id":"fish","term":"FISH","definition":"prose is not provenance"}]' > "$TMP/legacy/corpus/core.json"
printf '%s\n' 'legacy qualification' > "$TMP/legacy/qualification/Q.txt"
"$ROOT/gopher" sphere edit import-legacy "$TMP/legacy" --out "$TMP/fish-canonical" > "$TMP/import"
grep -q '"class": "CREATED"' "$TMP/import"
grep -q 'legacy evidence_note preserved as opaque legacy_evidence_note' "$TMP/import"
grep -q 'la la la la la la' "$TMP/fish-canonical/packs/fish-legacy/articles/fish-article.json"
grep -q 'legacy_evidence_note' "$TMP/fish-canonical/packs/fish-legacy/articles/fish-article.json"
if grep -q '"provenance"' "$TMP/fish-canonical/packs/fish-legacy/articles/fish-article.json"; then
  echo "legacy evidence prose was incorrectly promoted to provenance" >&2
  exit 1
fi
"$ROOT/gopher" sphere edit validate fish-legacy --path "$TMP/fish-canonical" > "$TMP/fish-valid"
grep -q '"class": "VALID"' "$TMP/fish-valid"

echo "PASS ALL LLM GOPHER v0.20 SPHERE SECTION/ROLLUP TESTS"
