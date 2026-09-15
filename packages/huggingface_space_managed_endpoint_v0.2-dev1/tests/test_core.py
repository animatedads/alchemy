from __future__ import annotations
import json, os, tempfile, zipfile
from pathlib import Path

import pytest

ROOT=Path(__file__).resolve().parents[1]
import sys
sys.path.insert(0, str(ROOT/'src'))

from managed_compute_core import ManagedEndpointExecutor, ManagedEndpointPolicy, default_registry, validate_bundle, ManagedJobError


def policy(tmp_path: Path):
    return ManagedEndpointPolicy(work_root=tmp_path/'work', result_root=tmp_path/'results', max_input_bytes=10_000_000, max_zip_members=100, max_zip_uncompressed_bytes=20_000_000, result_ttl_seconds=3600, max_result_files=8)


def make_bundle(path: Path):
    with zipfile.ZipFile(path,'w') as z:
        z.writestr('corpus/data.txt','say hello\n')


def test_cpu_smoke_happy_path_and_cleanup(tmp_path, monkeypatch):
    src=ROOT/'src'
    monkeypatch.chdir(src)
    bundle=tmp_path/'bundle.zip'; make_bundle(bundle)
    ex=ManagedEndpointExecutor(default_registry(src), policy(tmp_path))
    result, artifact=ex.execute(tier='CPU',request={'label':'probe-1'},input_bundle=bundle,control={'job_id':'job-1','operation_id':'MANAGED_SMOKE_V1','cleanup_remote':True,'tier':'CPU'})
    assert result['status']=='COMPLETED'
    assert result['cleanup']=='DONE'
    assert artifact and Path(artifact).is_file()
    assert result['artifact_name']==Path(artifact).name
    assert result['artifact_size']==Path(artifact).stat().st_size
    import hashlib
    assert result['artifact_sha256']==hashlib.sha256(Path(artifact).read_bytes()).hexdigest()
    assert list((tmp_path/'work').iterdir()) == []
    with zipfile.ZipFile(artifact) as z:
        assert 'outputs/smoke-result.json' in z.namelist()
        report=json.loads(z.read('outputs/smoke-result.json'))
        assert report['label']=='probe-1'
        manifest=json.loads(z.read('job-result.json'))
        assert manifest['operation_id']=='MANAGED_SMOKE_V1'


def test_gpu_is_not_used_for_cpu_operation(tmp_path):
    src=ROOT/'src'; bundle=tmp_path/'bundle.zip'; make_bundle(bundle)
    ex=ManagedEndpointExecutor(default_registry(src), policy(tmp_path))
    result, artifact=ex.execute(tier='ZEROGPU_LARGE',request={},input_bundle=bundle,control={'job_id':'job-2','operation_id':'MANAGED_SMOKE_V1','cleanup_remote':True,'tier':'ZEROGPU_LARGE'})
    assert result['code']=='OPERATION_TIER_NOT_ALLOWED'
    assert artifact is None


def test_gemma_operation_is_allowlisted_but_missing_script_fails_closed(tmp_path):
    src=ROOT/'src'; bundle=tmp_path/'bundle.zip'; make_bundle(bundle)
    ex=ManagedEndpointExecutor(default_registry(src), policy(tmp_path))
    result, artifact=ex.execute(tier='ZEROGPU_LARGE',request={'steps':100,'vocab_target':65536},input_bundle=bundle,control={'job_id':'gemma-1','operation_id':'GEMMA_OOREXX_RECOVERY_V1','cleanup_remote':True,'tier':'ZEROGPU_LARGE'})
    assert result['code']=='OPERATION_IMPLEMENTATION_MISSING'
    assert result['cleanup']=='DONE'
    assert artifact is None


def test_cleanup_flag_is_mandatory(tmp_path):
    src=ROOT/'src'; bundle=tmp_path/'bundle.zip'; make_bundle(bundle)
    ex=ManagedEndpointExecutor(default_registry(src), policy(tmp_path))
    result, artifact=ex.execute(tier='CPU',request={},input_bundle=bundle,control={'job_id':'job-3','operation_id':'MANAGED_SMOKE_V1','cleanup_remote':False,'tier':'CPU'})
    assert result['code']=='CLEANUP_REMOTE_REQUIRED'
    assert artifact is None


def test_zip_traversal_rejected(tmp_path):
    bundle=tmp_path/'evil.zip'
    with zipfile.ZipFile(bundle,'w') as z: z.writestr('../escape','x')
    with pytest.raises(ManagedJobError) as e:
        validate_bundle(bundle,max_bytes=10000,max_members=10,max_uncompressed_bytes=10000)
    assert e.value.code=='INPUT_BUNDLE_UNSAFE_PATH'


def test_caller_hf_token_not_inherited(tmp_path, monkeypatch):
    src=ROOT/'src'; bundle=tmp_path/'bundle.zip'; make_bundle(bundle)
    monkeypatch.setenv('HF_TOKEN','caller-write-token')
    ex=ManagedEndpointExecutor(default_registry(src), policy(tmp_path))
    op=ex.registry.resolve('MANAGED_SMOKE_V1')
    env=ex._minimal_env(op.extra_env_names)
    assert 'HF_TOKEN' not in env
