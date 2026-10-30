#!/usr/bin/env python3
"""Review-only staging of Rasen Falcon public preview through General Deployment.

Does not install files to system roots, publish routes, start servers, or accept
CMS/Brand/Wire release authority. The only writable target is a local /tmp
review workspace, deliberately separate from any Rasen Falcon host or unit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

PACKAGE = Path(__file__).resolve().parents[2]
SITE = PACKAGE / 'website'
LOCK_CHECK = PACKAGE / 'handoff/tools/website_source_lock.py'


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def workspace_path(name: str) -> Path:
    if not Path(name).is_absolute():
        raise ValueError('workspace must be an absolute path')
    base = Path(tempfile.gettempdir()).resolve()
    path = Path(name).resolve()
    if path == base or base not in path.parents or len(path.relative_to(base).parts) < 2:
        raise ValueError('workspace must be a dedicated subdirectory below the system temporary root')
    for part in [Path(name), *Path(name).parents]:
        if part == base:
            break
        if part.is_symlink():
            raise ValueError('workspace may not traverse symlinks')
    return path


def general_provider(root: Path) -> Path:
    executable = root / 'bin' / 'deploy_tree.sh'
    if (not executable.is_file() or executable.is_symlink()
            or not (root / 'VERSION').is_file()
            or (root / 'VERSION').read_text(encoding='utf-8').strip() != '0.1-dev4'):
        raise ValueError('General Deployment v0.1-dev4 provider is required; no fallback')
    return executable


def check_source() -> None:
    proc = subprocess.run([sys.executable, str(LOCK_CHECK), 'check'],
                          text=True, capture_output=True)
    if proc.returncode:
        raise ValueError('website source-lock failed: ' + (proc.stderr or proc.stdout).strip())


def build_preview(temp: Path) -> tuple[Path, dict]:
    output = temp / 'public-preview'
    proc = subprocess.run([sys.executable, str(SITE / 'tools/site.py'),
                           'build', '--mode', 'preview', '--output-dir', str(output)],
                          text=True, capture_output=True)
    if proc.returncode:
        raise ValueError('website preview compiler refused: ' + (proc.stderr or proc.stdout).strip())
    result = json.loads(proc.stdout)
    if result.get('pages') != 9 or result.get('mode') != 'preview':
        raise ValueError('wrong preview output contract')
    manifest = json.loads((output/'build-manifest.json').read_text(encoding='utf-8'))
    if (manifest.get('mode') != 'preview' or len(manifest.get('pages', [])) != 9
            or manifest.get('not_a_wire_release') is not True):
        raise ValueError('unqualified site build manifest')
    if 'Disallow: /' not in (output/'robots.txt').read_text():
        raise ValueError('preview robots disallow absent')
    for page in manifest['pages']:
        f = output/page['file']
        if not f.is_file() or digest(f) != page['sha256']:
            raise ValueError('page digest mismatch: ' + page.get('file','?'))
        markup = f.read_text(encoding='utf-8')
        if '<meta name="robots" content="noindex,nofollow">' not in markup:
            raise ValueError('preview page missing noindex: ' + page['slug'])
    return output, manifest


def source_inventory(source: Path) -> dict[str, str]:
    found = {}
    for f in source.rglob('*'):
        if f.is_symlink():
            raise ValueError('symlink inside staged preview')
        if f.is_file():
            rel=f.relative_to(source).as_posix()
            if rel != '.deployment-tree-sha256':
                found[rel] = digest(f)
    return found


def verify_stage(source: Path, target: Path) -> dict:
    current = target / 'current'
    if not current.is_symlink():
        raise ValueError('General Deployment staged current symlink absent')
    release = current.resolve(strict=True)
    if target.resolve()/'releases' not in release.parents:
        raise ValueError('staged current escapes the review target')
    declared = (release/'.deployment-tree-sha256')
    if not declared.is_file() or len(declared.read_text().strip()) != 64:
        raise ValueError('General Deployment generation marker missing')
    expected = source_inventory(source)
    actual = source_inventory(release)
    if actual != expected:
        raise ValueError('staged content differs from source preview')
    return {'generation':declared.read_text().strip(),'files':len(actual),
            'current':str(current),'release':str(release)}


def run(action: str, deployment_root: Path, workspace: Path) -> dict:
    provider=general_provider(deployment_root)
    check_source()
    if action == 'verify' and not workspace.is_dir():
        raise ValueError('review workspace has not been staged')
    with tempfile.TemporaryDirectory(prefix='rf-reviewed-preview-') as tmp:
        preview, manifest=build_preview(Path(tmp))
        target = workspace/'target'
        argv=['sh',str(provider),'--source',str(preview),'--target-root',str(target)]
        if action == 'plan':
            result=subprocess.run(argv+['--dry-run'],text=True,capture_output=True,check=True)
            return {'ok':True,'action':'plan','state':'SOURCE_ONLY','provider':'oorexx_deployment_v0.1-dev4',
                    'plan':result.stdout.strip(),'pages':9,'installed':'NOT_OBSERVED','running':'NOT_OBSERVED',
                    'production_release':False}
        if action == 'stage':
            workspace.mkdir(parents=True,exist_ok=True)
            proc=subprocess.run(argv,text=True,capture_output=True,check=True)
            evidence=verify_stage(preview,target)
            report={'schema':'rasenfalcon.deployment.review-evidence/0.1',
                    'state':'STAGED_LOCAL_REVIEW','provider':'oorexx_deployment_v0.1-dev4',
                    'source_digest':manifest['site_digest'],'pages':9,'generation':evidence['generation'],
                    'files':evidence['files'],'site_authority':'CANDIDATE_ONLY',
                    'installed':'NOT_OBSERVED','running':'NOT_OBSERVED','production_release':False}
            (workspace/'evidence.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
            return {'ok':True,'action':'stage',**report,'provider_output':proc.stdout.strip()}
        if action == 'verify':
            evidence=verify_stage(preview,target)
            return {'ok':True,'action':'verify','state':'STAGED_LOCAL_REVIEW',
                    'provider':'oorexx_deployment_v0.1-dev4','pages':9,**evidence,
                    'installed':'NOT_OBSERVED','running':'NOT_OBSERVED','production_release':False}
        raise ValueError('unsupported action')


def main() -> int:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['plan','stage','verify'])
    p.add_argument('--deployment-root',required=True,type=Path)
    p.add_argument('--workspace',required=True)
    ns=p.parse_args()
    try:
        w=workspace_path(ns.workspace)
        result=run(ns.action,ns.deployment_root,w)
        print(json.dumps(result,sort_keys=True))
        return 0
    except (OSError,ValueError,subprocess.CalledProcessError,KeyError,json.JSONDecodeError) as exc:
        print(json.dumps({'ok':False,'error':str(exc),'production_release':False}),file=sys.stderr)
        return 2

if __name__=='__main__':
    raise SystemExit(main())
