#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
LDAP_ROOT=${LDAP_DEV22_ROOT:-}
if [ -z "$LDAP_ROOT" ]; then
  echo 'SKIP Rasen Falcon identity role (set LDAP_DEV22_ROOT to dev22 extraction)'
  exit 0
fi
[ -f "$LDAP_ROOT/VERSION.txt" ] || { echo 'FAIL LDAP_DEV22_ROOT invalid' >&2; exit 1; }
w=$(mktemp -d "${TMPDIR:-/tmp}/rf-identity-role.XXXXXX")
trap 'rm -rf "$w"' EXIT HUP INT TERM
mkdir -p "$w/ns/components/Provider-abcd/src" "$w/ns/evidence"
printf '%s\n' 'dummy dependency' > "$w/ns/components/Provider-abcd/src/Dummy.cls"
printf '%s\n' "$w/ns/components/Provider-abcd/src" > "$w/ns/evidence/rexx-path.txt"
printf '%s\n' 'components/Provider-abcd/src' > "$w/ns/evidence/rexx-path.relative.txt"
: > "$w/ns/evidence/dependency.lock.tsv"
: > "$w/ns/evidence/component-roots.tsv"
: > "$w/ns/evidence/materialized-files.tsv"
printf "REXX_PATH='%s'\nexport REXX_PATH\n" "$w/ns/components/Provider-abcd/src" > "$w/ns/environment.sh"
( cd "$w/ns"; find components evidence -type f -print | sort | while IFS= read -r f; do sha256sum "$f"; done; sha256sum environment.sh ) > "$w/ns/MANIFEST.sha256"
"$ROOT/bin/verify_dependency_namespace.sh" "$w/ns" >/dev/null
"$ROOT/bin/build_rasenfalcon_identity_role.sh" \
  --ldap-root "$LDAP_ROOT" \
  --namespace "$w/ns" \
  --output "$w/role" \
  --ldap-archive-sha256 697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc \
  --ldap-source-commit 0495e8604c62fc780aff3c95b94c935415ffc57d >/dev/null
[ -f "$w/role/manifest.tsv" ]
[ -f "$w/role/files/ldap/bin/rasenfalcon_ldap_service.rex" ]
[ -f "$w/role/files/ldap/dependency-namespace/MANIFEST.sha256" ]
"$ROOT/bin/verify_dependency_namespace.sh" "$w/role/files/ldap/dependency-namespace" >/dev/null
cat > "$w/fake-rexx" <<'FAKE'
#!/bin/sh
printf '%s\n' "$REXX_PATH" > "$RF_CAPTURE"
exit 0
FAKE
chmod +x "$w/fake-rexx"
printf '%s\n' "say relocated" > "$w/program.rex"
RF_CAPTURE="$w/captured" OOREXX_REXX="$w/fake-rexx" "$ROOT/bin/launch_oorexx_namespace.sh" "$w/role/files/ldap/dependency-namespace" "$w/program.rex"
expected="$w/role/files/ldap/dependency-namespace/components/Provider-abcd/src"
[ "$(cat "$w/captured")" = "$expected" ] || { echo 'FAIL relocated REXX_PATH' >&2; exit 1; }
[ -f "$w/role/files/systemd/rasenfalcon-ldap.service" ]
grep -q 'launch_oorexx_namespace.sh /opt/rasenfalcon/ldap/dependency-namespace' "$w/role/files/systemd/rasenfalcon-ldap.service"
! grep -q '^ExecStart=/usr/bin/rexx ' "$w/role/files/systemd/rasenfalcon-ldap.service"
grep -qx 'rasenfalcon-ldap.service' "$w/role/services.txt"
[ "$(wc -l < "$w/role/tests.tsv" | tr -d ' ')" = 3 ]
grep -q '697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc' "$w/role/evidence/identity-role.tsv"
grep -q '0495e8604c62fc780aff3c95b94c935415ffc57d' "$w/role/evidence/identity-role.tsv"
# Manifest hashes must match their staged source files.
while IFS=$(printf '\t') read -r rel dst mode sha; do
  [ "$(sha256sum "$w/role/files/$rel" | awk '{print $1}')" = "$sha" ] || { echo "FAIL manifest hash $rel" >&2; exit 1; }
done < "$w/role/manifest.tsv"
echo 'PASS Rasen Falcon identity role packaging'
