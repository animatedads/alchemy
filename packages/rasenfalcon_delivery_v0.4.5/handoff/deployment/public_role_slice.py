#!/usr/bin/env python3
"""Assemble and independently verify the public site's site-only install slice.

This never supplies a systemd unit, readiness tests, TLS materials or a qualified
HTTPS runtime. Consequently the existing Rasen Falcon public check-release
MUST refuse until the owning HTTPS/Deployment providers complete the release.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from public_preview_staging import build_preview, check_source, source_inventory

PACKAGE = Path(__file__).resolve().parents[2]
SCHEMA = 'rasenfalcon.public-role.source-slice/0.1'
FILE_ROOT = 'roles/public/files/'
ALLOW_BASE = '/var/www/rasenfalcon/public/'
SCRIPT_TARGET = '/opt/rasenfalcon/public/server/serve.rex'


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_new_destination(dest: Path) -> None:
    if not dest.is_absolute() or dest.exists() or dest.is_symlink():
        raise ValueError('output must be an unused absolute path')
    if dest == Path('/') or len(dest.parts) < 4:
        raise ValueError('output must be inside a dedicated directory')
    if PACKAGE == dest or PACKAGE in dest.parents:
        raise ValueError('output cannot be inside source package')
    for node in (dest.parent, *dest.parent.parents):
        if node.is_symlink():
            raise ValueError('output parent symlink is forbidden')
    if not dest.parent.is_dir():
        raise ValueError('output parent directory does not exist')


def allowed_files(root: Path) -> dict[str, Path]:
    result = {}
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('preview contains a symbolic link')
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        if (not rel or any(p in ('.', '..') or p.startswith('.') for p in Path(rel).parts)
                or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/' for c in rel)):
            raise ValueError('unsafe source path')
        result[rel] = path
    if len(result) != 15 or not {'index.html', 'robots.txt', 'build-manifest.json'}.issubset(result):
        raise ValueError('unexpected preview file inventory')
    return result


def check_preview(root: Path) -> tuple[dict, dict[str, Path]]:
    items = allowed_files(root)
    manifest = json.loads(items['build-manifest.json'].read_text(encoding='utf8'))
    if manifest.get('mode') != 'preview' or manifest.get('not_a_wire_release') is not True:
        raise ValueError('only a candidate preview may be packaged')
    pages = manifest.get('pages')
    if not isinstance(pages, list) or len(pages) != 9:
        raise ValueError('exactly nine pages required')
    if 'Disallow: /' not in items['robots.txt'].read_text(encoding='utf8'):
        raise ValueError('robots.txt must deny indexing')
    paths = set()
    for page in pages:
        rel = page.get('file')
        if rel in paths or rel not in items or digest(items[rel]) != page.get('sha256'):
            raise ValueError('missing/modified page in source manifest')
        paths.add(rel)
        if '<meta name="robots" content="noindex,nofollow">' not in items[rel].read_text(encoding='utf8'):
            raise ValueError('preview page is indexable')
    return manifest, items


def build(output: Path) -> dict:
    safe_new_destination(output)
    check_source()
    with tempfile.TemporaryDirectory(prefix='rf-public-role-build-') as tmp:
        source, site_manifest = build_preview(Path(tmp))
        _, items = check_preview(source)
        with tempfile.TemporaryDirectory(dir=output.parent, prefix='.rf-site-slice-') as stage_dir:
            stage = Path(stage_dir)
            role = stage/'roles/public'
            manifest_rows = []
            for rel, src in items.items():
                dst_rel = 'site/'+rel
                target = role/'files'/dst_rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, target)
                manifest_rows.append((dst_rel, ALLOW_BASE+rel, '0644', digest(target)))
            rex_source = PACKAGE/'website/server/serve.rex'
            if not rex_source.is_file() or rex_source.is_symlink():
                raise ValueError('owned ooRexx preview adapter missing')
            rexx_target = role/'files/server/serve.rex'
            rexx_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(rex_source, rexx_target)
            manifest_rows.append(('server/serve.rex', SCRIPT_TARGET, '0644', digest(rexx_target)))
            manifest_rows.sort()
            (role/'manifest.tsv').write_text(''.join('\t'.join(x)+'\n' for x in manifest_rows), encoding='utf8')
            report = {
                'schema': SCHEMA,
                'state': 'SOURCE_SLICE_ONLY_NOT_INSTALL_READY',
                'provider': 'oorexx_deployment_v0.1-dev4',
                'source_package': 'rasenfalcon_delivery_v0.4.5',
                'site_digest': site_manifest['site_digest'],
                'pages': 9,
                'site_files': len(items),
                'files_in_manifest': len(manifest_rows),
                'https_runtime': 'EXTERNAL_QUALIFIED_CLOSURE_REQUIRED',
                'tls_identity': 'OPERATOR_PROVISIONED_NOT_IN_SOURCE',
                'service_unit': 'MISSING_FROM_SOURCE_SLICE',
                'readiness_e2e_tests': 'MISSING_FROM_SOURCE_SLICE',
                'installed': False,
                'running': False,
                'production_release': False,
            }
            (role/'public-slice.json').write_text(json.dumps(report,sort_keys=True,indent=2)+'\n', encoding='utf8')
            # Cross-filesystem rename is forbidden; the stage and destination share a parent.
            os.rename(stage, output)
            return report


def verify(output: Path) -> dict:
    if not output.is_dir() or output.is_symlink():
        raise ValueError('site slice missing or symlinked')
    role = output/'roles/public'
    report = json.loads((role/'public-slice.json').read_text(encoding='utf8'))
    if (report.get('schema') != SCHEMA or report.get('production_release') is not False
            or report.get('state') != 'SOURCE_SLICE_ONLY_NOT_INSTALL_READY'
            or report.get('installed') is not False or report.get('running') is not False):
        raise ValueError('source slice authority changed')
    if any((role/p).exists() for p in ('services.txt', 'tests.tsv')):
        raise ValueError('source slice must not claim owned service or test authority')
    manifest = role/'manifest.tsv'
    if manifest.is_symlink():
        raise ValueError('manifest symlink refused')
    rows = [line.split('\t') for line in manifest.read_text(encoding='utf8').splitlines()]
    found = set()
    for row in rows:
        if len(row) != 4:
            raise ValueError('invalid file manifest row')
        rel, dst, mode, sha = row
        if rel in found or not rel or '..' in Path(rel).parts or Path(rel).is_absolute():
            raise ValueError('unsafe or duplicate manifest file')
        found.add(rel)
        expect = SCRIPT_TARGET if rel == 'server/serve.rex' else ALLOW_BASE+rel.removeprefix('site/')
        if not (rel == 'server/serve.rex' or rel.startswith('site/')) or dst != expect or mode != '0644':
            raise ValueError('manifest destination outside site-only scope')
        fp = role/'files'/rel
        if fp.is_symlink() or not fp.is_file() or sha != digest(fp):
            raise ValueError('manifest file bytes differ')
    actual = source_inventory(role/'files')
    if set(actual) != found or len(rows) != 16 or report.get('files_in_manifest') != 16:
        raise ValueError('source slice inventory differs')
    site = role/'files/site'
    m, site_files = check_preview(site)
    if report.get('site_digest') != m.get('site_digest') or len(site_files) != 15:
        raise ValueError('source site digest differs')
    return {'ok':True,'state':'SOURCE_SLICE_VERIFIED_NOT_INSTALL_READY','pages':9,'files':len(rows),
            'site_digest':m['site_digest'],'installed':False,'running':False,'production_release':False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['assemble','verify'])
    p.add_argument('--output',required=True,type=Path)
    args = p.parse_args()
    try:
        result = build(args.output) if args.action=='assemble' else verify(args.output)
        print(json.dumps({'ok':True,**result},sort_keys=True))
        return 0
    except (ValueError,OSError,KeyError,json.JSONDecodeError) as exc:
        print(json.dumps({'ok':False,'error':str(exc),'production_release':False}),file=sys.stderr)
        return 2


if __name__=='__main__':
    raise SystemExit(main())
