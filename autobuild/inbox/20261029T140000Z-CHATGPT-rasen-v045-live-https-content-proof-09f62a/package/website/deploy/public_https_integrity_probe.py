#!/usr/bin/env python3
"""Real HTTPS content-integrity verification against a pinned local site tree.

Does not enable routes, approve publication, change DNS or infer RexxOS/LDAP health.
No hostile-path probe: triggering the owned HTTPS firewall can block the tester.
"""
import argparse
import hashlib
import http.client
import json
from pathlib import Path, PurePosixPath
import re
import ssl
import sys

SHA = re.compile(r"^[a-f0-9]{64}$")
HOSTS = {"rasenfalcon.com", "www.rasenfalcon.com"}
ASSETS = ("assets/site.css", "assets/site.js", "assets/favicon.svg", "robots.txt")
MAX_RESPONSE = 2_000_000

class ProbeError(ValueError):
    pass

def sha(data):
    return hashlib.sha256(data).hexdigest()

def _file(root, rel):
    if not isinstance(rel, str) or not rel or '\\' in rel or '\x00' in rel:
        raise ProbeError("invalid source path")
    path = PurePosixPath(rel)
    if path.is_absolute() or any(piece in ('..', '.', '') for piece in rel.split('/')):
        raise ProbeError("source traversal refused")
    candidate = root.joinpath(*path.parts)
    if not candidate.is_file() or candidate.is_symlink() or root.resolve() not in candidate.resolve().parents:
        raise ProbeError("missing/untrusted source: " + rel)
    if candidate.stat().st_size > MAX_RESPONSE:
        raise ProbeError("oversized source: " + rel)
    return candidate.read_bytes()

def inventory(root):
    root = Path(root).resolve(strict=True)
    manifest = json.loads(_file(root, 'build-manifest.json'))
    if manifest.get('mode') not in ('preview', 'production'):
        raise ProbeError('unrecognized build mode')
    pages = manifest.get('pages')
    if not isinstance(pages, list) or len(pages) != 9:
        raise ProbeError('expected exactly nine pages')
    wanted = {}
    seen = set()
    for p in pages:
        rel, path, checksum = p.get('file'), p.get('path'), p.get('sha256')
        if not isinstance(rel, str) or not rel.endswith('/index.html') and rel != 'index.html':
            raise ProbeError('invalid page source')
        if not isinstance(path, str) or (path != '/' and not re.fullmatch(r'/[a-z0-9-]+/', path)):
            raise ProbeError('invalid page URL')
        if not SHA.fullmatch(checksum or '') or sha(_file(root,rel)) != checksum:
            raise ProbeError('page source digest mismatch: ' + rel)
        if path in seen:
            raise ProbeError('duplicate URL path')
        seen.add(path)
        wanted[path] = checksum
    if '/' not in wanted:
        raise ProbeError('home page absent')
    for asset in ASSETS:
        wanted['/'+asset] = sha(_file(root,asset))
    return {'mode':manifest['mode'], 'expected':wanted, 'root':str(root)}

def probe(host,port,root,ca_file=None,expect_leaf_sha256=None,timeout=6):
    inv = inventory(root)
    if not isinstance(host,str) or not re.fullmatch(r'[a-zA-Z0-9.-]+',host):
        raise ProbeError('invalid hostname')
    if not isinstance(port,int) or not 1 <= port <= 65535:
        raise ProbeError('invalid port')
    if expect_leaf_sha256 and not SHA.fullmatch(expect_leaf_sha256):
        raise ProbeError('invalid expected certificate digest')
    ctx = ssl.create_default_context(cafile=ca_file) if ca_file else ssl.create_default_context()
    ctx.check_hostname = True
    ctx.verify_mode = ssl.CERT_REQUIRED
    checks=[]
    for path,checksum in inv['expected'].items():
        conn = http.client.HTTPSConnection(host,port=port,context=ctx,timeout=timeout)
        try:
            conn.connect()  # verifies issuer, hostname / SNI and certificate lifetime
            tls = conn.sock.version()
            if tls not in ('TLSv1.2','TLSv1.3'):
                raise ProbeError('TLS version below policy minimum')
            cert = conn.sock.getpeercert(binary_form=True)
            if expect_leaf_sha256 and sha(cert) != expect_leaf_sha256:
                raise ProbeError('TLS server certificate fingerprint mismatch')
            conn.request('GET',path,headers={'Accept-Encoding':'identity','Connection':'close'})
            res = conn.getresponse()
            if res.status != 200:
                raise ProbeError(f'{path}: expected 200, received {res.status} (redirects prohibited)')
            if res.getheader('Content-Encoding','identity').lower() != 'identity':
                raise ProbeError(f'{path}: compressed body not byte-identical')
            body = res.read(MAX_RESPONSE+1)
            if len(body) > MAX_RESPONSE:
                raise ProbeError(f'{path}: response size exceeded limit')
            if sha(body) != checksum:
                raise ProbeError(f'{path}: content SHA-256 mismatch')
            checks.append({'path':path,'status':200,'sha256':checksum})
        except (OSError,ssl.SSLError,http.client.HTTPException) as exc:
            raise ProbeError(f'{path}: HTTPS probe failed: {exc}') from exc
        finally:
            conn.close()
    return {'schema':'rasenfalcon.public-https-integrity/0.1','ok':True,
            'host':host,'port':port,'mode':inv['mode'],
            'checks':checks,'checks_passed':len(checks),
            'content_integrity':'PASS','tls_server_verified':True,
            'cms_release_authorized':'NOT_TESTED','private_mtls':'NOT_TESTED',
            'service_installed':'NOT_TESTED','production_approved':False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--site-root',required=True,type=Path)
    p.add_argument('--host',default='rasenfalcon.com')
    p.add_argument('--port',type=int,default=443)
    p.add_argument('--ca-file',type=Path)
    p.add_argument('--expect-leaf-sha256')
    p.add_argument('--timeout',type=float,default=6)
    a=p.parse_args()
    try:
        if a.host not in HOSTS:
            raise ProbeError('only the declared public RasenFalcon authorities may be probed')
        if a.timeout <= 0 or a.timeout > 30:
            raise ProbeError('timeout outside bounded range')
        print(json.dumps(probe(a.host,a.port,a.site_root,a.ca_file,a.expect_leaf_sha256,a.timeout),sort_keys=True))
        return 0
    except (ProbeError,OSError,ValueError,ssl.SSLError) as e:
        print(json.dumps({'ok':False,'error':str(e),'production_approved':False}),file=sys.stderr)
        return 2
if __name__ == '__main__':
    raise SystemExit(main())
