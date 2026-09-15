from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Mapping

SAFE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
SAFE_OPERATION_RE = re.compile(r"^[A-Z0-9][A-Z0-9_.-]{0,127}$")


class ManagedJobError(RuntimeError):
    def __init__(self, code: str, detail: str = "") -> None:
        self.code = code
        self.detail = detail
        super().__init__(f"{code}: {detail}" if detail else code)


def _safe_int(value: Any, *, name: str, minimum: int, maximum: int) -> int:
    try:
        result = int(value)
    except (TypeError, ValueError) as exc:
        raise ManagedJobError("PARAMETER_INVALID", name) from exc
    if result < minimum or result > maximum:
        raise ManagedJobError("PARAMETER_OUT_OF_RANGE", name)
    return result


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def validate_bundle(path: Path, *, max_bytes: int, max_members: int, max_uncompressed_bytes: int) -> dict[str, Any]:
    if not path.is_file():
        raise ManagedJobError("INPUT_BUNDLE_MISSING")
    size = path.stat().st_size
    if size > max_bytes:
        raise ManagedJobError("INPUT_BUNDLE_TOO_LARGE", str(size))
    info: dict[str, Any] = {"size": size, "sha256": _sha256(path), "zip": False, "members": 0, "uncompressed_bytes": 0}
    if not zipfile.is_zipfile(path):
        return info
    info["zip"] = True
    total = 0
    with zipfile.ZipFile(path, "r") as zf:
        members = zf.infolist()
        if len(members) > max_members:
            raise ManagedJobError("INPUT_BUNDLE_TOO_MANY_MEMBERS", str(len(members)))
        for zi in members:
            name = zi.filename.replace("\\", "/")
            p = Path(name)
            if p.is_absolute() or ".." in p.parts or name.startswith("/"):
                raise ManagedJobError("INPUT_BUNDLE_UNSAFE_PATH", name)
            mode = (zi.external_attr >> 16) & 0o170000
            if mode == 0o120000:
                raise ManagedJobError("INPUT_BUNDLE_SYMLINK_FORBIDDEN", name)
            total += zi.file_size
            if total > max_uncompressed_bytes:
                raise ManagedJobError("INPUT_BUNDLE_EXPANSION_LIMIT", str(total))
    info["members"] = len(members)
    info["uncompressed_bytes"] = total
    return info


@dataclass(frozen=True)
class ManagedScriptOperation:
    operation_id: str
    script_path: Path
    allowed_tiers: frozenset[str]
    argument_builder: Callable[[Mapping[str, Any], Path, Path], list[str]]
    timeout_seconds: int = 1800
    extra_env_names: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        op = self.operation_id.upper()
        if not SAFE_OPERATION_RE.fullmatch(op):
            raise ValueError(f"unsafe operation id: {self.operation_id}")
        object.__setattr__(self, "operation_id", op)
        object.__setattr__(self, "allowed_tiers", frozenset(x.upper() for x in self.allowed_tiers))


@dataclass
class ManagedOperationRegistry:
    operations: dict[str, ManagedScriptOperation] = field(default_factory=dict)

    def register(self, operation: ManagedScriptOperation) -> None:
        if operation.operation_id in self.operations:
            raise ValueError(f"duplicate managed operation: {operation.operation_id}")
        self.operations[operation.operation_id] = operation

    def resolve(self, operation_id: str) -> ManagedScriptOperation:
        op = self.operations.get(operation_id.upper())
        if op is None:
            raise ManagedJobError("OPERATION_NOT_ALLOWED", operation_id)
        return op


@dataclass
class ManagedEndpointPolicy:
    work_root: Path = Path(os.environ.get("REXXAPI_MANAGED_WORK_ROOT", "/tmp/rexxapi-managed-jobs"))
    result_root: Path = Path(os.environ.get("REXXAPI_MANAGED_RESULT_ROOT", "/tmp/rexxapi-managed-results"))
    max_input_bytes: int = int(os.environ.get("REXXAPI_MANAGED_MAX_INPUT_BYTES", str(4 * 1024**3)))
    max_zip_members: int = int(os.environ.get("REXXAPI_MANAGED_MAX_ZIP_MEMBERS", "20000"))
    max_zip_uncompressed_bytes: int = int(os.environ.get("REXXAPI_MANAGED_MAX_UNCOMPRESSED_BYTES", str(12 * 1024**3)))
    result_ttl_seconds: int = int(os.environ.get("REXXAPI_MANAGED_RESULT_TTL_SECONDS", str(6 * 3600)))
    max_result_files: int = int(os.environ.get("REXXAPI_MANAGED_MAX_RESULT_FILES", "32"))


class ManagedEndpointExecutor:
    def __init__(self, registry: ManagedOperationRegistry, policy: ManagedEndpointPolicy | None = None) -> None:
        self.registry = registry
        self.policy = policy or ManagedEndpointPolicy()
        self.policy.work_root.mkdir(parents=True, exist_ok=True)
        self.policy.result_root.mkdir(parents=True, exist_ok=True)

    def execute(self, *, tier: str, request: Mapping[str, Any] | None, input_bundle: str | os.PathLike[str] | None, control: Mapping[str, Any] | None) -> tuple[dict[str, Any], str | None]:
        started = time.time()
        tier = tier.upper()
        request = dict(request or {})
        control = dict(control or {})
        job_id = str(control.get("job_id", "")).strip()
        operation_id = str(control.get("operation_id", "")).strip().upper()
        if not SAFE_ID_RE.fullmatch(job_id):
            return self._failure("JOB_ID_INVALID", operation_id, tier, started), None
        if not SAFE_OPERATION_RE.fullmatch(operation_id):
            return self._failure("OPERATION_ID_INVALID", operation_id, tier, started), None
        if control.get("cleanup_remote") is not True:
            return self._failure("CLEANUP_REMOTE_REQUIRED", operation_id, tier, started), None
        declared_tier = str(control.get("tier", "")).upper()
        if declared_tier != tier:
            return self._failure("TIER_MISMATCH", operation_id, tier, started), None
        try:
            operation = self.registry.resolve(operation_id)
        except ManagedJobError as exc:
            return self._failure(exc.code, operation_id, tier, started, exc.detail), None
        if tier not in operation.allowed_tiers:
            return self._failure("OPERATION_TIER_NOT_ALLOWED", operation_id, tier, started), None
        if input_bundle is None:
            return self._failure("INPUT_BUNDLE_REQUIRED", operation_id, tier, started), None
        bundle = Path(str(input_bundle))
        try:
            bundle_info = validate_bundle(
                bundle,
                max_bytes=self.policy.max_input_bytes,
                max_members=self.policy.max_zip_members,
                max_uncompressed_bytes=self.policy.max_zip_uncompressed_bytes,
            )
        except ManagedJobError as exc:
            return self._failure(exc.code, operation_id, tier, started, exc.detail), None

        self._gc_results()
        workspace = Path(tempfile.mkdtemp(prefix=f"{job_id}-", dir=self.policy.work_root))
        output_dir = workspace / "output"
        output_dir.mkdir(parents=True, exist_ok=True)
        stdout_path = workspace / "stdout.log"
        stderr_path = workspace / "stderr.log"
        artifact_path: Path | None = None
        result: dict[str, Any]
        try:
            script = operation.script_path
            if not script.is_absolute():
                script = (Path.cwd() / script).resolve()
            if not script.is_file():
                raise ManagedJobError("OPERATION_IMPLEMENTATION_MISSING", str(operation.script_path))
            args = operation.argument_builder(request, bundle, output_dir)
            if not isinstance(args, list) or not all(isinstance(x, str) for x in args):
                raise ManagedJobError("OPERATION_ARGUMENT_BUILDER_INVALID")
            env = self._minimal_env(operation.extra_env_names)
            with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
                try:
                    proc = subprocess.run(
                        [os.environ.get("PYTHON", "python3"), str(script), *args],
                        cwd=workspace,
                        env=env,
                        stdin=subprocess.DEVNULL,
                        stdout=stdout,
                        stderr=stderr,
                        timeout=operation.timeout_seconds,
                        check=False,
                    )
                except subprocess.TimeoutExpired as exc:
                    raise ManagedJobError("OPERATION_TIMEOUT", str(operation.timeout_seconds)) from exc
            if proc.returncode != 0:
                raise ManagedJobError("OPERATION_FAILED", str(proc.returncode))
            artifact_path = self._build_result_bundle(
                job_id=job_id,
                operation_id=operation_id,
                tier=tier,
                bundle_info=bundle_info,
                output_dir=output_dir,
                stdout_path=stdout_path,
                stderr_path=stderr_path,
                started=started,
            )
            result = {
                "status": "COMPLETED",
                "code": "OK",
                "job_id": job_id,
                "operation_id": operation_id,
                "tier": tier,
                "cleanup": "PENDING",
                "input": bundle_info,
                "elapsed_seconds": round(time.time() - started, 3),
                "artifact_name": artifact_path.name,
            }
        except ManagedJobError as exc:
            result = self._failure(exc.code, operation_id, tier, started, exc.detail, job_id=job_id, bundle_info=bundle_info)
        except Exception as exc:  # fail closed without leaking arbitrary exception detail to the caller
            result = self._failure("REMOTE_EXECUTION_INTERNAL_ERROR", operation_id, tier, started, type(exc).__name__, job_id=job_id, bundle_info=bundle_info)
        finally:
            shutil.rmtree(workspace, ignore_errors=True)

        # The cleanup receipt is asserted only after workspace removal.  The result
        # artifact lives in a separate bounded result cache and never contains caller credentials.
        result["cleanup"] = "DONE" if not workspace.exists() else "FAILED"
        if result["cleanup"] != "DONE":
            result["status"] = "FAILED"
            result["code"] = "REMOTE_CLEANUP_FAILED"
            artifact_path = None
        return result, str(artifact_path) if artifact_path and artifact_path.exists() else None

    def _minimal_env(self, extra_names: tuple[str, ...]) -> dict[str, str]:
        env: dict[str, str] = {}
        for key in ("PATH", "HOME", "LANG", "LC_ALL", "HF_HOME", "TRANSFORMERS_CACHE"):
            if key in os.environ:
                env[key] = os.environ[key]
        for key in extra_names:
            if key in os.environ:
                env[key] = os.environ[key]
        # Caller bearer credentials are intentionally not inherited.  A model-specific
        # read token must be installed as a distinct Space secret and explicitly named by
        # the operation's extra_env_names.
        env.pop("HF_TOKEN", None)
        env.pop("HUGGING_FACE_HUB_TOKEN", None)
        if "HF_MODEL_READ_TOKEN" in extra_names and os.environ.get("HF_MODEL_READ_TOKEN"):
            env["HF_TOKEN"] = os.environ["HF_MODEL_READ_TOKEN"]
        return env

    def _build_result_bundle(self, *, job_id: str, operation_id: str, tier: str, bundle_info: Mapping[str, Any], output_dir: Path, stdout_path: Path, stderr_path: Path, started: float) -> Path:
        stamp = int(time.time() * 1000)
        dest = self.policy.result_root / f"{job_id}-{stamp}.zip"
        manifest: dict[str, Any] = {
            "schema": "rexxapi.managed-space-result/0.1",
            "job_id": job_id,
            "operation_id": operation_id,
            "tier": tier,
            "input": dict(bundle_info),
            "started_epoch": started,
            "completed_epoch": time.time(),
            "files": [],
        }
        with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED, allowZip64=True) as zf:
            for src, arc in ((stdout_path, "logs/stdout.log"), (stderr_path, "logs/stderr.log")):
                if src.is_file() and not src.is_symlink():
                    zf.write(src, arc)
                    manifest["files"].append({"path": arc, "size": src.stat().st_size, "sha256": _sha256(src)})
            if output_dir.is_dir():
                for src in sorted(output_dir.rglob("*")):
                    if not src.is_file() or src.is_symlink():
                        continue
                    rel = src.relative_to(output_dir)
                    if ".." in rel.parts:
                        continue
                    arc = str(Path("outputs") / rel).replace("\\", "/")
                    zf.write(src, arc)
                    manifest["files"].append({"path": arc, "size": src.stat().st_size, "sha256": _sha256(src)})
            zf.writestr("job-result.json", json.dumps(manifest, sort_keys=True, separators=(",", ":")))
        return dest

    def _failure(self, code: str, operation_id: str, tier: str, started: float, detail: str = "", *, job_id: str = "", bundle_info: Mapping[str, Any] | None = None) -> dict[str, Any]:
        return {
            "status": "FAILED",
            "code": code,
            "job_id": job_id,
            "operation_id": operation_id,
            "tier": tier,
            "cleanup": "DONE",
            "detail": detail[:240],
            "input": dict(bundle_info or {}),
            "elapsed_seconds": round(time.time() - started, 3),
        }

    def _gc_results(self) -> None:
        now = time.time()
        files = [p for p in self.policy.result_root.glob("*.zip") if p.is_file()]
        for p in files:
            try:
                if now - p.stat().st_mtime > self.policy.result_ttl_seconds:
                    p.unlink(missing_ok=True)
            except OSError:
                pass
        files = sorted((p for p in self.policy.result_root.glob("*.zip") if p.is_file()), key=lambda p: p.stat().st_mtime, reverse=True)
        for p in files[self.policy.max_result_files :]:
            try:
                p.unlink(missing_ok=True)
            except OSError:
                pass


def gemma_recovery_arguments(request: Mapping[str, Any], input_bundle: Path, output_dir: Path) -> list[str]:
    base = str(request.get("base", "google/gemma-2-2b-it"))
    if len(base) > 200 or not re.fullmatch(r"[A-Za-z0-9_.\-/]+", base):
        raise ManagedJobError("PARAMETER_INVALID", "base")
    vocab_target = _safe_int(request.get("vocab_target", 65536), name="vocab_target", minimum=8192, maximum=262144)
    recovery_steps = _safe_int(request.get("recovery_steps", request.get("steps", 100)), name="recovery_steps", minimum=1, maximum=5000)
    return [
        "--input", str(input_bundle),
        "--base", base,
        "--vocab-target", str(vocab_target),
        "--recovery-steps", str(recovery_steps),
        "--output", str(output_dir),
    ]


def smoke_arguments(request: Mapping[str, Any], input_bundle: Path, output_dir: Path) -> list[str]:
    label = str(request.get("label", "managed-smoke"))
    if not SAFE_ID_RE.fullmatch(label):
        raise ManagedJobError("PARAMETER_INVALID", "label")
    return ["--input", str(input_bundle), "--output", str(output_dir), "--label", label]


def default_registry(repo_root: str | os.PathLike[str] | None = None) -> ManagedOperationRegistry:
    root = Path(repo_root or os.environ.get("REXXAPI_SPACE_REPO_ROOT", Path.cwd()))
    registry = ManagedOperationRegistry()
    registry.register(
        ManagedScriptOperation(
            operation_id="MANAGED_SMOKE_V1",
            script_path=root / "managed_smoke.py",
            allowed_tiers=frozenset({"CPU"}),
            argument_builder=smoke_arguments,
            timeout_seconds=120,
        )
    )
    registry.register(
        ManagedScriptOperation(
            operation_id="GEMMA_OOREXX_RECOVERY_V1",
            script_path=root / os.environ.get("GEMMA_OOREXX_TRAIN_SCRIPT", "train_gemma_oorexx.py"),
            allowed_tiers=frozenset({"ZEROGPU_LARGE", "ZEROGPU_XLARGE"}),
            argument_builder=gemma_recovery_arguments,
            timeout_seconds=int(os.environ.get("GEMMA_OOREXX_MAX_SECONDS", "1800")),
            extra_env_names=("HF_MODEL_READ_TOKEN",),
        )
    )
    return registry
