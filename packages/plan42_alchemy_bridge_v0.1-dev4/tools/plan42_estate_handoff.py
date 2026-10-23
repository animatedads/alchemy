#!/usr/bin/env python3
"""Read-only source/compile-receipt projection for the wider Alchemy estate.

Authority boundary: these are local candidate records. An exact file hash is
NOT Semantic Source Store approval, Runtime Registry publication, or execution.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

from plan42_bridge import ROOT, GENERATED, SCHEMA as BRIDGE_SCHEMA, discover, inspect, inside

MANIFEST = ROOT / 'estate' / 'plan42.estate.candidate.json'
SCHEMA = 'alchemy.plan42.estate-handoff/0.1'


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def estate_manifest() -> dict[str, Any]:
    data = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if data.get('schema') != 'alchemy.plan42.estate-candidate/0.1' or data.get('status') != 'UNREGISTERED_CANDIDATE':
        raise ValueError('estate manifest authority contract is invalid')
    return data


def read_receipt(path: str, checked_source_hash: str) -> dict[str, Any]:
    """Validate local compiler evidence; refuse anything claiming execution/publication."""
    candidate = Path(path).resolve()
    if not inside(ROOT, candidate) or not candidate.is_file() or candidate.is_symlink():
        raise ValueError('receipt must be a local regular file inside the Alchemy workspace')
    receipt = json.loads(candidate.read_text(encoding='utf-8'))
    if not isinstance(receipt, dict) or receipt.get('schema') != BRIDGE_SCHEMA:
        raise ValueError('unsupported compiler receipt schema')
    if receipt.get('ok') is not True or receipt.get('operation') != 'compile':
        raise ValueError('only successful Plan42 compile receipts are accepted')
    if any(receipt.get(k) is not False for k in ('executed','published','dispatched')):
        raise ValueError('receipt is not strictly no-execute/no-publication')
    if receipt.get('source_sha256') != checked_source_hash:
        raise ValueError('receipt source digest does not match current source')
    out = receipt.get('output')
    if not isinstance(out, str) or not out:
        raise ValueError('missing output path')
    artifact = (ROOT / out).resolve()
    if not inside(GENERATED,artifact) or not artifact.is_file() or artifact.is_symlink():
        raise ValueError('compiler output is outside the staging root')
    if digest(artifact) != receipt.get('output_sha256'):
        raise ValueError('generated output has changed since compilation')
    if receipt.get('status') != 'generated':
        raise ValueError('receipt status must be generated')
    return {'target':receipt.get('target'), 'target_maturity':receipt.get('target_maturity'),
            'source_sha256':checked_source_hash, 'artifact_sha256':digest(artifact),
            'compiler_engine':receipt.get('engine'), 'compatibility':receipt.get('compatibility'),
            'artifact':str(artifact.relative_to(ROOT)), 'verified':'LOCAL_DIGEST_ONLY',
            'executed':False,'published':False,'dispatched':False}


def handoff(spec_name: str, receipt_path: str|None = None) -> dict[str, Any]:
    estate_manifest()
    base = inspect(spec_name)  # canonical safe-path checks and source sha
    receipt = read_receipt(receipt_path, base['source_sha256']) if receipt_path else None
    return {'schema':SCHEMA,'ok':True,'status':'CANDIDATE_NOT_PUBLISHED',
            'component':'alchemy.plan42','service_api':BRIDGE_SCHEMA,
            'source':{'local_path':base['source'],'sha256':base['source_sha256'],
                      'semantic_source_store_revision':None,'source_authority':'UNATTESTED_LOCAL'},
            'plan42':{'module':base['module'],'spec_version':base['spec'],
                      'preferred_references':base['preferred_references'],
                      'node_counts':base['node_counts'],
                      'security_findings':base['security_findings']},
            'compiler_receipt':receipt,'operation':'handoff',
            'required_gates':{'runtime_registry_publication':False,
                              'semantic_source_store_commit':False,
                              'codelet_define_approval':False,
                              'remote_rpc_dispatch':False,
                              'execution':False},
            'consumer_intentions':['plan42.inspect','plan42.compile'],
            'no_automatic_transport':True,'no_implicit_queue':True,
            'evidence_class':'LOCAL_UNVERIFIED_CANDIDATE'}


def verify_archives(package_dir: Path) -> dict[str,Any]:
    m=estate_manifest()
    if not package_dir.is_dir():
        raise ValueError('package directory does not exist')
    results=[]
    for a in m['source_artifacts']:
        p=package_dir/a['name']
        if not p.is_file() or p.is_symlink():
            results.append({'name':a['name'],'status':'MISSING'})
        else:
            actual=digest(p)
            results.append({'name':a['name'],'status':'MATCH' if actual==a['sha256'] else 'MISMATCH',
                            'sha256':actual})
    return {'schema':SCHEMA,'ok':all(x['status']=='MATCH' for x in results),
            'operation':'verify-pins','packages':results,'binding':'LIBRARY_COPY_CHECK_ONLY'}


def main(argv: list[str]|None=None) -> int:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['manifest','prepare','verify-pins'])
    p.add_argument('--spec')
    p.add_argument('--receipt')
    p.add_argument('--package-dir')
    ns=p.parse_args(argv)
    try:
        if ns.action=='manifest':
            result=estate_manifest()
        elif ns.action=='verify-pins':
            if not ns.package_dir:raise ValueError('--package-dir is required')
            result=verify_archives(Path(ns.package_dir))
        else:
            if not ns.spec:raise ValueError('--spec is required')
            result=handoff(ns.spec,ns.receipt)
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        result={'schema':SCHEMA,'ok':False,'status':'REFUSED','message':str(exc)}
    print(json.dumps(result,sort_keys=True,ensure_ascii=True))
    return 0 if result.get('ok',True) else 1

if __name__=='__main__':
    sys.exit(main())
