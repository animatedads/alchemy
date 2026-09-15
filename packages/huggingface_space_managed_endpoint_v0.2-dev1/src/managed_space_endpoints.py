from __future__ import annotations

import os
from typing import Any

import gradio as gr

from managed_compute_core import ManagedEndpointExecutor, default_registry

try:
    import spaces  # provided by Hugging Face ZeroGPU Spaces
except ImportError:
    if os.environ.get("REXXAPI_MANAGED_ENDPOINT_TEST_MODE") != "1":
        raise

    class _TestSpaces:
        @staticmethod
        def GPU(*_args: Any, **_kwargs: Any):
            def decorate(fn):
                return fn
            return decorate

    spaces = _TestSpaces()


_EXECUTOR = ManagedEndpointExecutor(default_registry())


def _bundle_path(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        value = value.get("path") or value.get("name")
        return str(value) if value else None
    path = getattr(value, "path", None) or getattr(value, "name", None)
    return str(path) if path else str(value)


def _duration(_request: Any, _input_bundle: Any, control: Any) -> int:
    try:
        seconds = int((control or {}).get("expected_gpu_seconds", 60))
    except (AttributeError, TypeError, ValueError):
        seconds = 60
    cap = int(os.environ.get("REXXAPI_ZEROGPU_MAX_DECLARED_SECONDS", "1200"))
    return max(1, min(seconds, cap))


def _run(tier: str, request: Any, input_bundle: Any, control: Any):
    result, artifact = _EXECUTOR.execute(
        tier=tier,
        request=request if isinstance(request, dict) else {},
        input_bundle=_bundle_path(input_bundle),
        control=control if isinstance(control, dict) else {},
    )
    return result, artifact


def job_cpu(request: dict | None, input_bundle: Any, _job: dict | None):
    return _run("CPU", request, input_bundle, _job)


@spaces.GPU(duration=_duration)
def job_large(request: dict | None, input_bundle: Any, _job: dict | None):
    return _run("ZEROGPU_LARGE", request, input_bundle, _job)


@spaces.GPU(duration=_duration, size="xlarge")
def job_xlarge(request: dict | None, input_bundle: Any, _job: dict | None):
    return _run("ZEROGPU_XLARGE", request, input_bundle, _job)


def attach_managed_endpoints() -> None:
    """Attach hidden, named managed-compute endpoints inside an active Blocks context.

    Call this while constructing the Space's existing ``gr.Blocks`` application.
    The endpoints share one concurrency id/limit so a single Space cannot be abused
    as an unbounded parallel job runner.
    """
    with gr.Group(visible=False):
        request = gr.JSON(label="request")
        input_bundle = gr.File(label="input_bundle", file_count="single", type="filepath")
        control = gr.JSON(label="_job")
        result = gr.JSON(label="result")
        artifact = gr.File(label="artifact")
        cpu = gr.Button("managed-cpu", visible=False)
        large = gr.Button("managed-zerogpu-large", visible=False)
        xlarge = gr.Button("managed-zerogpu-xlarge", visible=False)

    common = dict(
        inputs=[request, input_bundle, control],
        outputs=[result, artifact],
        concurrency_id="rexxapi-managed-compute",
        concurrency_limit=1,
        show_progress="hidden",
    )
    cpu.click(fn=job_cpu, api_name="job_cpu", **common)
    large.click(fn=job_large, api_name="job_large", **common)
    xlarge.click(fn=job_xlarge, api_name="job_xlarge", **common)
