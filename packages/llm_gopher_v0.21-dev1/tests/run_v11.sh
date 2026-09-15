#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src/tests" "$TMP/src/__pycache__" "$TMP/src/.git"
printf 'x\n' > "$TMP/src/app.py"
printf 'x\n' > "$TMP/src/__pycache__/x.pyc"
printf 'x\n' > "$TMP/src/.git/config"
cat > "$TMP/src/tests/run.sh" <<'EOF'
#!/bin/sh
: "${DEMO_TOKEN:-}"
EOF
chmod +x "$TMP/src/tests/run.sh"
"$ROOT/gopher" --profile oorexx package check --in "$TMP/src" --version v0.11-dev1 > "$TMP/bad.json"
grep -q '"PACKAGE.CONTENT.EXCLUDED"' "$TMP/bad.json"
grep -q '"PACKAGE.CHANGELOG.REQUIRED"' "$TMP/bad.json"
"$ROOT/gopher" --profile oorexx package stage --in "$TMP/src" --to "$TMP/stage" > "$TMP/stage.json"
test ! -e "$TMP/stage/__pycache__"
test ! -e "$TMP/stage/.git"
cat > "$TMP/stage/CHANGELOG.md" <<'EOF'
# Changelog
## v0.11-dev1
EOF
"$ROOT/gopher" --profile oorexx package check --in "$TMP/stage" --version v0.11-dev1 > "$TMP/good.json"
grep -q '"class": "READY"' "$TMP/good.json"
grep -q '"name": "DEMO_TOKEN"' "$TMP/good.json"
echo "PASS ALL LLM GOPHER v0.11 PACKAGE/STAGING TESTS"
