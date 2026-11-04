#!/usr/bin/env python3
"""Offline Publisher -> Rasenfalcon candidate preview, no publication authority.

This is operator-side *development tooling*; it is neither a Python web server
nor an application persistence implementation. Content authority stays with
CMS/NoSQLServer and site release stays with the Rasenfalcon/Wire owners.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

SCHEMA = 'alchemy.website.publisher.preview-bundle/0.1'


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()


def run_builder(builder: Path, *args: object) -> dict:
    proc = subprocess.run([sys.executable, str(builder / 'tools' / 'site.py'), *(str(a) for a in args)],
                          cwd=builder, capture_output=True, text=True, check=False, timeout=90)
    try:
        reply = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise ValueError('site builder returned non-JSON output') from exc
    if proc.returncode or not isinstance(reply, dict) or reply.get('ok') is not True:
        raise ValueError('Rasenfalcon builder rejected request: ' + str(reply.get('error', 'unknown error')))
    return reply


def ensure_safe_path(path: Path, *, directory=False) -> Path:
    if path.is_symlink():
        raise ValueError('symbolic links are forbidden: ' + str(path))
    if directory and not path.is_dir():
        raise ValueError('builder directory required: ' + str(path))
    if not directory and not path.is_file():
        raise ValueError('regular candidate file required: ' + str(path))
    return path.resolve(strict=True)


def compile_candidate(candidate: Path, builder: Path, output: Path) -> dict:
    # Refuse ambient production paths and follow no user-supplied symlink.
    candidate = ensure_safe_path(candidate)
    builder = ensure_safe_path(builder, directory=True)
    if not (builder / 'tools' / 'site.py').is_file():
        raise ValueError('Rasenfalcon v0.2 site builder missing')
    if not (builder / 'docs' / 'PUBLISHER_HANDOFF_V0.2.md').is_file():
        raise ValueError('Rasenfalcon v0.2 handoff contract missing')
    if candidate.stat().st_size > 3_000_000:
        raise ValueError('candidate exceeds 3 MB')
    output = output.absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('output already exists; refusing replacement')
    parent = output.parent
    if not parent.is_dir() or parent.is_symlink():
        raise ValueError('output parent must be an existing, non-symlink directory')
    if output == builder or output == candidate or builder in output.parents or output in builder.parents:
        raise ValueError('output cannot overlap the site builder')
    if output == candidate.parent or output in candidate.parents:
        raise ValueError('output cannot overlap candidate input')
    old_umask = os.umask(0o077)
    temp = None
    try:
        temp = Path(tempfile.mkdtemp(prefix='.publisher-preview-', dir=parent))
        stage = temp / 'staged'
        preview = temp / 'preview'
        stage_result = run_builder(builder, 'stage-publisher', candidate, stage)
        report = json.loads((stage / 'staging.json').read_text(encoding='utf-8'))
        if not (report.get('schema') == 'rasenfalcon.publisher-stage/0.1'
                and report.get('state') == 'CANDIDATE_UNREVIEWED'
                and report.get('authority') == 'NONE'
                and report.get('site') == 'rasenfalcon.com'
                and report.get('native_revision_verified') is False
                and report.get('production_build_allowed') is False
                and report.get('cms_release_receipts') == []
                and report.get('wire_release_receipts') == []
                and len(report.get('pages', [])) == 9
                and report.get('input_sha256') == sha256(candidate)):
            raise ValueError('unsafe or incomplete Rasenfalcon staging receipt')
        build_result = run_builder(builder, 'build', '--mode', 'preview',
                                   '--content-dir', stage / 'content', '--output-dir', preview)
        bm = json.loads((preview / 'build-manifest.json').read_text(encoding='utf-8'))
        html_files = sorted(preview.rglob('index.html'))
        if not (build_result.get('mode') == 'preview' and build_result.get('pages') == 9
                and bm.get('schema') == 'rasenfalcon.build/0.1'
                and bm.get('mode') == 'preview'
                and bm.get('not_a_wire_release') is True
                and len(bm.get('pages', [])) == 9 and len(html_files) == 9
                and 'Disallow: /' in (preview / 'robots.txt').read_text(encoding='utf-8')
                and all('noindex,nofollow' in p.read_text(encoding='utf-8') for p in html_files)):
            raise ValueError('preview privacy, page count, or release boundary failed')
        for entry in bm['pages']:
            html_path = preview / entry['file']
            if not html_path.is_file() or sha256(html_path) != entry['sha256']:
                raise ValueError('preview page hash mismatch')
        receipt = {
            'schema': SCHEMA, 'site': 'rasenfalcon.com',
            'state': 'CANDIDATE_PREVIEW_BUILT', 'authority': 'NONE',
            'publication_authority': 'NONE', 'deployment': 'NOT_PERFORMED',
            'native_revision_verified': False,
            'input_sha256': sha256(candidate),
            'stage_report_sha256': sha256(stage / 'staging.json'),
            'build_manifest_sha256': sha256(preview / 'build-manifest.json'),
            'site_digest': bm['site_digest'], 'page_count': 9,
            'notes': 'Local preview evidence only; no verified CMS/Brand/Wire release',
        }
        (temp / 'publisher-preview-receipt.json').write_text(json.dumps(receipt, sort_keys=True, indent=2) + '\n', encoding='utf-8')
        if output.exists() or output.is_symlink():
            raise ValueError('output appeared during compilation; refusing replacement')
        # Same-filesystem rename presents an already-validated private candidate tree.
        # The caller must reserve an output name not concurrently used by another writer.
        temp.rename(output)
        temp = None
        return receipt
    finally:
        if temp is not None:
            shutil.rmtree(temp, ignore_errors=True)
        os.umask(old_umask)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description='Offline candidate-only Rasenfalcon stage and preview; NEVER deploys')
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--builder', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args(argv)
    try:
        result = compile_candidate(args.candidate, args.builder, args.output)
        print(json.dumps({'ok': True, 'receipt': result, 'output': str(args.output.absolute())}, sort_keys=True))
        return 0
    except (ValueError, OSError, subprocess.TimeoutExpired, UnicodeError) as e:
        print(json.dumps({'ok': False, 'error': str(e), 'deployment': 'NOT_PERFORMED'}, sort_keys=True))
        return 2

if __name__ == '__main__':
    sys.exit(main())
