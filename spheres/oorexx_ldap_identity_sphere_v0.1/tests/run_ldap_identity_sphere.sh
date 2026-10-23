#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
files=list(root.glob('packs/ldap-identity/*.json'))+[root/'profiles/ldap-identity.json']
for p in files:
    json.loads(p.read_text())
assert any(json.loads(p.read_text()).get('kind')=='sphere' for p in root.glob('packs/ldap-identity/*.json'))
print('JSON STRUCTURE: PASS')
PY

grep -q 'same authority epoch' "$ROOT/packs/ldap-identity/10-corpus-ldap-identity.continuity.json" ||   grep -q 'same authority epoch' "$ROOT/packs/ldap-identity/03-article-ldap-identity.authority.json"
grep -q 'XTP transport ACK' "$ROOT/packs/ldap-identity/10-corpus-ldap-identity.continuity.json"
grep -q '14d41d9c1cd339ccd99bc1a344b182fdb86ef2b5c30ee6454dd2fbfe1525d8ec' "$ROOT/packs/ldap-identity/02-article-ldap-identity.current.json"

if [ -x "$ROOT/gopher" ]; then
  "$ROOT/gopher" --profile ldap-identity context ldap-identity > "$TMP/context.json"
  grep -q 'ldap-identity.current' "$TMP/context.json"
  "$ROOT/gopher" --profile ldap-identity search 'same epoch holder' --sphere ldap-identity > "$TMP/epoch.json"
  grep -q 'FOUND' "$TMP/epoch.json"
  "$ROOT/gopher" --profile ldap-identity search 'XTP transport ACK' --sphere ldap-identity > "$TMP/xtp.json"
  grep -q 'FOUND' "$TMP/xtp.json"
fi

echo 'PASS ooRexx LDAP Identity sphere v0.1 structural qualification'
