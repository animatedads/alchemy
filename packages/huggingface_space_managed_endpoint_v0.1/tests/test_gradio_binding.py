from __future__ import annotations
import os, sys
from pathlib import Path
os.environ['REXXAPI_MANAGED_ENDPOINT_TEST_MODE']='1'
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'src'))
import gradio as gr
from managed_space_endpoints import attach_managed_endpoints, _duration


def test_named_endpoints_are_attached():
    with gr.Blocks() as demo:
        attach_managed_endpoints()
    info=demo.get_api_info()
    names=set(info['named_endpoints'])
    assert '/job_cpu' in names
    assert '/job_large' in names
    assert '/job_xlarge' in names


def test_duration_uses_declared_gpu_seconds_and_cap(monkeypatch):
    monkeypatch.setenv('REXXAPI_ZEROGPU_MAX_DECLARED_SECONDS','1200')
    assert _duration({},None,{'expected_gpu_seconds':100})==100
    assert _duration({},None,{'expected_gpu_seconds':99999})==1200
    assert _duration({},None,{})==60
