#!/bin/sh
# Build the Rasen Falcon identity role from the owned LDAP package and a sealed
# General Deployment dependency namespace. This creates a reviewable release
# role only; it never installs, starts services, provisions identities or issues
# certificates.
set -eu
usage(){ cat >&2 <<'USAGE'
usage: build_rasenfalcon_identity_role.sh \
  --ldap-root DIR --namespace DIR --output DIR \
  --ldap-archive-sha256 HEX64 --ldap-source-commit HEX40
USAGE
}
ldap=''; ns=''; out=''; archive=''; commit=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ldap-root) ldap=$2; shift 2;;
    --namespace) ns=$2; shift 2;;
    --output) out=$2; shift 2;;
    --ldap-archive-sha256) archive=$2; shift 2;;
    --ldap-source-commit) commit=$2; shift 2;;
    *) usage; exit 2;;
  esac
done
[ -d "$ldap" ] && [ -d "$ns" ] && [ -n "$out" ] || { usage; exit 2; }
case "$archive" in *[!0-9a-f]*|'') echo 'FAIL LDAP archive SHA-256 must be lowercase hex' >&2; exit 2;; esac
[ ${#archive} -eq 64 ] || { echo 'FAIL LDAP archive SHA-256 length' >&2; exit 2; }
case "$commit" in *[!0-9a-f]*|'') echo 'FAIL LDAP source commit must be lowercase hex' >&2; exit 2;; esac
[ ${#commit} -eq 40 ] || { echo 'FAIL LDAP source commit length' >&2; exit 2; }
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
for f in \
  "$ldap/bin/rasenfalcon_ldap_service.rex" \
  "$ldap/deployment/rasenfalcon/rasenfalcon-ldap.service" \
  "$ldap/deployment/rasenfalcon/ldap.env.example" \
  "$ldap/deployment/rasenfalcon/ldap-secrets.map.example" \
  "$ldap/tests/deployment/test_rasenfalcon_deployment_contract.sh"; do
  [ -f "$f" ] || { echo "FAIL LDAP deployment input absent: $f" >&2; exit 4; }
done
[ -f "$ldap/MANIFEST.sha256" ] || { echo 'FAIL LDAP package manifest absent' >&2; exit 4; }
( cd "$ldap" && sha256sum -c MANIFEST.sha256 >/dev/null ) || { echo 'FAIL LDAP package manifest verification' >&2; exit 4; }
sh "$ldap/tests/deployment/test_rasenfalcon_deployment_contract.sh" >/dev/null || { echo 'FAIL LDAP deployment contract test' >&2; exit 4; }
"$ROOT/bin/verify_dependency_namespace.sh" "$ns" >/dev/null

tmp=${out}.tmp.$$
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
rm -rf "$tmp"
mkdir -p "$tmp/files/ldap" "$tmp/files/systemd" "$tmp/files/config" "$tmp/tests" "$tmp/evidence"
# Full LDAP package is retained because the daemon's package-relative ::requires
# are part of the owned component. Dependencies outside LDAP come only from the
# separately sealed namespace below.
cp -a "$ldap/." "$tmp/files/ldap/"
mkdir -p "$tmp/files/ldap/dependency-namespace"
cp -a "$ns/." "$tmp/files/ldap/dependency-namespace/"
mkdir -p "$tmp/files/ldap/deployment"
cp "$ROOT/bin/launch_oorexx_namespace.sh" "$tmp/files/ldap/deployment/launch_oorexx_namespace.sh"
chmod 0755 "$tmp/files/ldap/deployment/launch_oorexx_namespace.sh"
# Preserve the LDAP-owned unit hardening contract, changing only the launch seam
# so the exact verified namespace is used instead of ambient package discovery.
awk '
  /^ExecStart=/ {
    print "ExecStart=/opt/rasenfalcon/ldap/deployment/launch_oorexx_namespace.sh /opt/rasenfalcon/ldap/dependency-namespace /opt/rasenfalcon/ldap/bin/rasenfalcon_ldap_service.rex"
    next
  }
  { print }
' "$ldap/deployment/rasenfalcon/rasenfalcon-ldap.service" > "$tmp/files/systemd/rasenfalcon-ldap.service"
cp "$ldap/deployment/rasenfalcon/ldap.env.example" "$tmp/files/config/ldap.env.example"
cp "$ldap/deployment/rasenfalcon/ldap-secrets.map.example" "$tmp/files/config/ldap-secrets.map.example"
printf '%s\n' rasenfalcon-ldap.service > "$tmp/services.txt"

cat > "$tmp/tests/ready_ldap_bind.sh" <<'PROBE'
#!/bin/sh
set -eu
: "${RF_LDAP_TEST_HOST:?NOT_RUN RF_LDAP_TEST_HOST required}"
: "${RF_LDAP_TEST_PORT:=636}"
: "${RF_LDAP_TEST_CA:?NOT_RUN RF_LDAP_TEST_CA required}"
: "${RF_LDAP_TEST_DN:?NOT_RUN RF_LDAP_TEST_DN required}"
: "${RF_LDAP_TEST_PASSWORD:?NOT_RUN RF_LDAP_TEST_PASSWORD required}"
: "${RF_LDAP_TEST_BASE:?NOT_RUN RF_LDAP_TEST_BASE required}"
python3 - "$RF_LDAP_TEST_HOST" "$RF_LDAP_TEST_PORT" "$RF_LDAP_TEST_CA" "$RF_LDAP_TEST_DN" "$RF_LDAP_TEST_PASSWORD" "$RF_LDAP_TEST_BASE" <<'PY'
import socket, ssl, sys
host,port,cafile,dn,pw,base=sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4],sys.argv[5],sys.argv[6]
def L(n):
    if n<128:return bytes([n])
    b=n.to_bytes((n.bit_length()+7)//8,'big'); return bytes([0x80|len(b)])+b
def T(t,v=b''):return bytes([t])+L(len(v))+v
def I(n,t=2):
    b=b'\0' if n==0 else n.to_bytes((n.bit_length()+7)//8,'big')
    if b[0]&0x80:b=b'\0'+b
    return T(t,b)
def O(x):return T(4,x.encode())
def M(mid,op):return T(0x30,I(mid)+op)
def bind(mid):return M(mid,T(0x60,I(3)+O(dn)+T(0x80,pw.encode())))
def search(mid):
    flt=T(0x87,b'objectClass')
    body=O(base)+I(0,0x0a)+I(0,0x0a)+I(1)+I(3)+T(1,b'\0')+flt+T(0x30,O('objectClass'))
    return M(mid,T(0x63,body))
def rx(s,n):
    b=b''
    while len(b)<n:
        q=s.recv(n-len(b))
        if not q: raise EOFError
        b+=q
    return b
def frame(s):
    h=rx(s,2); n=h[1]
    if n&0x80:
        c=n&0x7f; e=rx(s,c); n=int.from_bytes(e,'big'); h+=e
    return h+rx(s,n)
def tlv(d,o=0):
    t=d[o];o+=1;n=d[o];o+=1
    if n&0x80:
        c=n&0x7f;n=int.from_bytes(d[o:o+c],'big');o+=c
    return t,d[o:o+n],o+n
def result(f):
    _,v,_=tlv(f);_,_,p=tlv(v);tag,op,_=tlv(v,p);_,rv,_=tlv(op);return tag,int.from_bytes(rv,'big')
ctx=ssl.create_default_context(cafile=cafile)
with socket.create_connection((host,port),timeout=8) as raw:
    with ctx.wrap_socket(raw,server_hostname=host) as s:
        s.sendall(bind(1)); tag,rc=result(frame(s)); assert (tag,rc)==(0x61,0),(tag,rc)
        s.sendall(search(2)); tag,rc=result(frame(s)); assert tag in (0x64,0x65),(tag,rc)
print('PASS ready:ldap_bind')
PY
PROBE

cat > "$tmp/tests/e2e_ldap_revoke.sh" <<'PROBE'
#!/bin/sh
set -eu
probe=${RF_LDAP_REVOKE_PROBE:-/opt/rasenfalcon/ldap/activation/live_ldap_revoke_probe.sh}
[ -x "$probe" ] || { echo "NOT_RUN owned live LDAP revoke probe absent: $probe" >&2; exit 2; }
exec "$probe"
PROBE
cat > "$tmp/tests/e2e_sign_verify_revoke.sh" <<'PROBE'
#!/bin/sh
set -eu
probe=${RF_SIGN_VERIFY_REVOKE_PROBE:-/opt/rasenfalcon/pki/bin/live_sign_verify_revoke_probe.sh}
[ -x "$probe" ] || { echo "NOT_RUN owned Crypto/PKI live sign/verify/revoke probe absent: $probe" >&2; exit 2; }
exec "$probe"
PROBE
chmod 0755 "$tmp/tests/"*.sh

# Rasen Falcon controller install manifest. The config examples are installed as
# examples only; real /etc/rasenfalcon/ldap.env and ldap-secrets.map remain
# operator/secret-authority inputs and are never generated from source.
: > "$tmp/manifest.tsv"
find "$tmp/files/ldap" -type f -print | LC_ALL=C sort | while IFS= read -r src; do
  rel=${src#"$tmp/files/"}
  sub=${rel#ldap/}
  mode=0644
  [ -x "$src" ] && mode=0755
  sha=$(sha256sum "$src" | awk '{print $1}')
  printf '%s\t/opt/rasenfalcon/ldap/%s\t%s\t%s\n' "$rel" "$sub" "$mode" "$sha"
done >> "$tmp/manifest.tsv"
sha=$(sha256sum "$tmp/files/systemd/rasenfalcon-ldap.service" | awk '{print $1}')
printf 'systemd/rasenfalcon-ldap.service\t/etc/systemd/system/rasenfalcon-ldap.service\t0644\t%s\n' "$sha" >> "$tmp/manifest.tsv"
for n in ldap.env.example ldap-secrets.map.example; do
  sha=$(sha256sum "$tmp/files/config/$n" | awk '{print $1}')
  printf 'config/%s\t/etc/rasenfalcon/%s\t0600\t%s\n' "$n" "$n" "$sha" >> "$tmp/manifest.tsv"
done
: > "$tmp/tests.tsv"
for spec in 'ready ldap_bind tests/ready_ldap_bind.sh' 'e2e ldap_revoke tests/e2e_ldap_revoke.sh' 'e2e sign_verify_revoke tests/e2e_sign_verify_revoke.sh'; do
  set -- $spec; phase=$1; name=$2; rel=$3
  sha=$(sha256sum "$tmp/$rel" | awk '{print $1}')
  printf '%s\t%s\t%s\t%s\n' "$phase" "$name" "$rel" "$sha" >> "$tmp/tests.tsv"
done
ns_manifest_sha=$(sha256sum "$ns/MANIFEST.sha256" | awk '{print $1}')
cat > "$tmp/evidence/identity-role.tsv" <<EOF2
schema\trasenfalcon.identity-role/0.1
ldap_archive_sha256\t$archive
ldap_source_commit\t$commit
dependency_namespace_manifest_sha256\t$ns_manifest_sha
install_root\t/opt/rasenfalcon/ldap
service\trasenfalcon-ldap.service
activation\tOPERATOR_GATED
live_status\tNOT_RUN
EOF2
# Self-check the generated unit and exact test inventory.
grep -q '^User=rasenfalcon-ldap$' "$tmp/files/systemd/rasenfalcon-ldap.service"
grep -q '^NoNewPrivileges=true$' "$tmp/files/systemd/rasenfalcon-ldap.service"
grep -q 'launch_oorexx_namespace.sh /opt/rasenfalcon/ldap/dependency-namespace' "$tmp/files/systemd/rasenfalcon-ldap.service"
! grep -q '^ExecStart=/usr/bin/rexx ' "$tmp/files/systemd/rasenfalcon-ldap.service"
grep -qx 'rasenfalcon-ldap.service' "$tmp/services.txt"
awk -F '\t' '$1=="ready" && $2=="ldap_bind" {ok=1} END{exit !ok}' "$tmp/tests.tsv"
awk -F '\t' '$1=="e2e" && $2=="ldap_revoke" {ok=1} END{exit !ok}' "$tmp/tests.tsv"
awk -F '\t' '$1=="e2e" && $2=="sign_verify_revoke" {ok=1} END{exit !ok}' "$tmp/tests.tsv"
rm -rf "$out.new.$$"; mv "$tmp" "$out.new.$$"; trap 'rm -rf "$out.new.$$"' EXIT HUP INT TERM
rm -rf "$out"; mv "$out.new.$$" "$out"; trap - EXIT HUP INT TERM
printf 'READY rasenfalcon-identity-role=%s service=rasenfalcon-ldap.service status=NOT_RUN\n' "$out"
