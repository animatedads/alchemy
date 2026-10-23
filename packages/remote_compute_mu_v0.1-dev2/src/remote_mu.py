"""Remote Compute MU reference controller, v0.1-dev2.

It deliberately does not issue placement or WLU authority, operate a local queue,
or expose a live Colab/ZeroGPU/Windows transport. Those bindings must be injected.
"""
from __future__ import annotations

from contextlib import contextmanager
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Mapping, Protocol
import fcntl
import hashlib
import json
import os
import re
import time

PROVIDERS = frozenset({'colab', 'zerogpu', 'windows_vm', 'windows_container'})
TERMINAL = frozenset({'SUCCEEDED', 'FAILED', 'CANCELLED', 'LOST'})
STATES = frozenset({'ACCEPTED', 'ADMITTED', 'STAGING', 'SUBMITTING', 'UNCERTAIN',
                    'SUBMITTED', 'RUNNING', 'CANCEL_REQUESTED', 'COMMITTING', 'SUCCEEDED',
                    'FAILED', 'CANCELLED', 'LOST', 'HELD'})
JOB_RE = re.compile(r'^[A-Za-z0-9_-]{1,128}$')
DIGEST_RE = re.compile(r'^[a-f0-9]{64}$')

class MUError(Exception):
    pass

class Rejected(MUError):
    pass

class Conflict(MUError):
    pass

class PlacementAuthority(Protocol):
    def check(self, lease: Mapping[str, Any], request: Mapping[str, Any]) -> bool: ...

class EntitlementAuthority(Protocol):
    def check(self, receipt: Mapping[str, Any], request: Mapping[str, Any]) -> bool: ...

class StorageAuthority(Protocol):
    def input_ready(self, ref: str) -> bool: ...
    def output_commit(self, ref: str, manifest: Mapping[str, Any]) -> None: ...

class RuntimeBackend(Protocol):
    def submit(self, job: Mapping[str, Any]) -> str: ...
    def poll(self, remote_id: str) -> Mapping[str, Any]: ...
    def cancel(self, remote_id: str) -> None: ...
    def reconcile(self, dispatch_key: str) -> Mapping[str, Any] | None: ...

@dataclass
class Record:
    job_id: str
    fingerprint: str
    backend: str
    state: str = 'ACCEPTED'
    remote_id: str | None = None
    dispatch_key: str | None = None
    output_ref: str | None = None
    updated: float = field(default_factory=time.time)
    history: list[dict[str, Any]] = field(default_factory=list)


class RemoteComputeMU:
    """Single-controller durable intent, fencing preflight and remote reconciliation.

    The lock is local; deployment with multiple controllers requires an external
    ownership lease/fence and must NOT share this journal without such a layer.
    """
    def __init__(self, root: str, placement: PlacementAuthority,
                 entitlement: EntitlementAuthority, storage: StorageAuthority,
                 backends: Mapping[str, RuntimeBackend]):
        self.root = Path(root)
        self.root.mkdir(mode=0o700, parents=True, exist_ok=True)
        if self.root.is_symlink() or self.root.stat().st_mode & 0o077:
            raise Rejected('INSECURE_JOURNAL_DIRECTORY')
        self.placement, self.entitlement, self.storage = placement, entitlement, storage
        self.backends = dict(backends)
        self.lock_path = self.root / '.controller.lock'
        with os.fdopen(os.open(self.lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600), 'r+') as f:
            os.fchmod(f.fileno(), 0o600)

    @contextmanager
    def _locked(self):
        fd = os.open(self.lock_path, os.O_RDWR | os.O_NOFOLLOW)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            yield
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)

    def _path(self, job_id: str) -> Path:
        if not isinstance(job_id, str) or JOB_RE.fullmatch(job_id) is None:
            raise Rejected('BAD_JOB_ID')
        return self.root / (job_id + '.json')

    def _read(self, job_id: str) -> Record | None:
        path = self._path(job_id)
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        except FileNotFoundError:
            return None
        with os.fdopen(fd, 'r', encoding='utf-8') as f:
            r = Record(**json.load(f))
        if r.job_id != job_id or r.state not in STATES:
            raise Rejected('CORRUPT_JOURNAL_RECORD')
        return r

    def get(self, job_id: str) -> Record | None:
        with self._locked():
            return self._read(job_id)

    def _save(self, rec: Record) -> None:
        target = self._path(rec.job_id)
        unique = self.root / ('.' + rec.job_id + '-' + str(os.getpid()) + '.tmp')
        fd = os.open(unique, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as f:
                json.dump(asdict(rec), f, sort_keys=True, allow_nan=False)
                f.flush()
                os.fsync(f.fileno())
            os.replace(unique, target)
            dir_fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        finally:
            if unique.exists():
                unique.unlink()

    def _set(self, rec: Record, state: str) -> None:
        if state not in STATES:
            raise Rejected('UNKNOWN_STATE')
        rec.state = state
        rec.updated = time.time()
        rec.history.append({'state': state, 'at': rec.updated})
        self._save(rec)

    @staticmethod
    def _validate(req: Mapping[str, Any]) -> str:
        required = {'jobId', 'backend', 'workload', 'inputRef', 'outputRef', 'lease', 'entitlement'}
        if not isinstance(req, dict) or not required.issubset(req):
            raise Rejected('MISSING_FIELDS')
        if req['backend'] not in PROVIDERS:
            raise Rejected('BACKEND_UNAVAILABLE')
        if not isinstance(req['workload'], dict) or not isinstance(req['workload'].get('type'), str):
            raise Rejected('BAD_WORKLOAD')
        if not isinstance(req['inputRef'], str) or not req['inputRef']:
            raise Rejected('BAD_INPUT_REF')
        if not isinstance(req['outputRef'], str) or not req['outputRef']:
            raise Rejected('BAD_OUTPUT_REF')
        for authority in ('lease', 'entitlement'):
            if not isinstance(req[authority], dict):
                raise Rejected('BAD_AUTHORITY_ENVELOPE')
        w = req['workload']
        if req['backend'] == 'colab':
            if w.get('resource') not in {'CPU', 'GPU', 'TPU'}:
                raise Rejected('COLAB_RESOURCE_REQUIRED')
            if w['resource'] in {'GPU', 'TPU'} and not w.get('accelerator'):
                raise Rejected('COLAB_ACCELERATOR_REQUIRED')
            if w['resource'] == 'CPU' and w.get('accelerator'):
                raise Rejected('CPU_WITH_ACCELERATOR')
        if req['backend'] == 'zerogpu':
            if not isinstance(w.get('space'), str) or '/' not in w['space'] or not w.get('operation'):
                raise Rejected('ZEROGPU_SPACE_OPERATION_REQUIRED')
            if w.get('exclusiveGpu') is True:
                raise Rejected('ZEROGPU_EXCLUSIVE_GPU_UNSUPPORTED')
        if req['backend'] == 'windows_container':
            if w.get('requiresWindowsKernel') is not True or w.get('isolation') != 'windows':
                raise Rejected('WINDOWS_CONTAINER_REQUIRES_WINDOWS_HOST')
            if not w.get('imageDigest'):
                raise Rejected('PINNED_CONTAINER_IMAGE_REQUIRED')
        if req['backend'] == 'windows_vm' and not w.get('imageRef'):
            raise Rejected('WINDOWS_VM_IMAGE_REQUIRED')
        return hashlib.sha256(json.dumps(req, sort_keys=True, separators=(',', ':'),
                                         allow_nan=False).encode('utf-8')).hexdigest()

    def _accept(self, req: Mapping[str, Any]) -> Record:
        fp = self._validate(req)
        jid = req['jobId']
        old = self._read(jid)
        if old:
            if old.fingerprint != fp:
                raise Conflict('JOB_ID_REUSE_DIFFERENT_CONTENT')
            return old
        if req['backend'] not in self.backends:
            raise Rejected('BACKEND_UNAVAILABLE')
        if not self.entitlement.check(req['entitlement'], req):
            raise Rejected('ENTITLEMENT_DENIED')
        if not self.placement.check(req['lease'], req):
            raise Rejected('PLACEMENT_LEASE_DENIED')
        if not self.storage.input_ready(req['inputRef']):
            raise Rejected('INPUT_NOT_DURABLE')
        rec = Record(jid, fp, req['backend'], output_ref=req['outputRef'])
        self._set(rec, 'ACCEPTED')
        return rec

    def accept(self, req: Mapping[str, Any]) -> Record:
        self._path(req.get('jobId') if isinstance(req, dict) else None)
        with self._locked():
            return self._accept(req)

    def dispatch(self, req: Mapping[str, Any]) -> Record:
        self._path(req.get('jobId') if isinstance(req, dict) else None)
        with self._locked():
            rec = self._accept(req)
            if rec.state != 'ACCEPTED':
                return rec  # In particular, NEVER retry UNCERTAIN, STAGING, or HELD.
            if (not self.entitlement.check(req['entitlement'], req)
                    or not self.placement.check(req['lease'], req)):
                self._set(rec, 'HELD')
                return rec
            self._set(rec, 'ADMITTED')
            self._set(rec, 'STAGING')
            # Persist immutable dispatch identity before the external side effect.
            rec.dispatch_key = hashlib.sha256(('mu-dispatch/1:' + rec.job_id + ':' + rec.fingerprint).encode()).hexdigest()
            self._set(rec, 'SUBMITTING')
            outbound = dict(req)
            outbound['dispatchKey'] = rec.dispatch_key
            try:
                remote_id = self.backends[rec.backend].submit(outbound)
                if not isinstance(remote_id, str) or not remote_id:
                    raise Rejected('INVALID_REMOTE_ID')
            except Exception:
                self._set(rec, 'UNCERTAIN')
                raise
            rec.remote_id = remote_id
            self._set(rec, 'SUBMITTED')
            return rec

    def recover(self, job_id: str) -> Record:
        """Non-dispatching reconciliation; never retries a possible side effect."""
        with self._locked():
            rec = self._read(job_id)
            if rec is None:
                raise Rejected('UNKNOWN_JOB')
            if rec.state not in {'SUBMITTING', 'UNCERTAIN'}:
                return rec
            backend = self.backends[rec.backend]
            receipt = backend.reconcile(rec.dispatch_key)
            if receipt is None:
                self._set(rec, 'UNCERTAIN')
                return rec
            if (not isinstance(receipt, dict) or receipt.get('dispatchKey') != rec.dispatch_key
                    or not isinstance(receipt.get('remoteId'), str) or not receipt['remoteId']):
                raise Rejected('UNTRUSTED_RECONCILIATION_EVIDENCE')
            rec.remote_id = receipt['remoteId']
            self._set(rec, 'SUBMITTED')
            return rec

    def refresh(self, job_id: str) -> Record:
        with self._locked():
            rec = self._read(job_id)
            if rec is None:
                raise Rejected('UNKNOWN_JOB')
            if rec.state not in {'SUBMITTED', 'RUNNING', 'CANCEL_REQUESTED'}:
                return rec
            result = self.backends[rec.backend].poll(rec.remote_id)
            if not isinstance(result, dict) or result.get('state') not in {
                    'SUBMITTED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED', 'LOST'}:
                raise Rejected('UNTRUSTED_BACKEND_STATUS')
            state = result['state']
            if state == 'SUCCEEDED':
                manifest = result.get('outputManifest')
                if (not isinstance(manifest, dict) or not isinstance(manifest.get('sha256'), str)
                        or DIGEST_RE.fullmatch(manifest['sha256']) is None
                        or not isinstance(manifest.get('size'), int) or manifest['size'] < 0):
                    self._set(rec, 'HELD')
                    return rec
                # Journal COMMITTING first. A crash after a storage side effect
                # must never automatically replay that effect. Storage authority
                # must reconcile before manual release of the held operation.
                self._set(rec, 'COMMITTING')
                self.storage.output_commit(rec.output_ref, manifest)
            if rec.state == 'CANCEL_REQUESTED' and state in {'SUBMITTED', 'RUNNING'}:
                return rec
            self._set(rec, state)
            return rec

    def cancel(self, job_id: str) -> Record:
        with self._locked():
            rec = self._read(job_id)
            if rec is None:
                raise Rejected('UNKNOWN_JOB')
            if rec.state in TERMINAL or rec.state == 'CANCEL_REQUESTED':
                return rec
            if rec.state in {'SUBMITTING', 'UNCERTAIN'}:
                return rec  # Cannot falsely report cancellation of unknown remote work.
            if rec.remote_id is None:
                self._set(rec, 'CANCELLED')  # Nothing was submitted.
                return rec
            self._set(rec, 'CANCEL_REQUESTED')
            self.backends[rec.backend].cancel(rec.remote_id)
            return rec  # Provider confirmation required before CANCELLED.


class DisabledBackend:
    def __init__(self, name: str):
        self.name = name
    def submit(self, job):
        raise Rejected(self.name.upper() + '_LIVE_ADAPTER_NOT_BOUND')
    def poll(self, remote_id):
        raise Rejected('LIVE_ADAPTER_NOT_BOUND')
    def cancel(self, remote_id):
        raise Rejected('LIVE_ADAPTER_NOT_BOUND')
    def reconcile(self, dispatch_key):
        return None

class SimulatorBackend:
    """Tests only: NOT a production provider. Requires explicit injection."""
    def __init__(self):
        self.jobs = {}
        self.by_key = {}
        self.submissions = 0
        self.error_after_effect = False
    def submit(self, job):
        key = job['dispatchKey']
        if key not in self.by_key:
            self.submissions += 1
            rid = 'sim:' + job['jobId']
            self.by_key[key] = rid
            self.jobs[rid] = {'state': 'RUNNING'}
        if self.error_after_effect:
            raise OSError('simulated reply lost after remote acceptance')
        return self.by_key[key]
    def poll(self, remote_id):
        return self.jobs[remote_id]
    def cancel(self, remote_id):
        self.jobs[remote_id] = {'state': 'CANCELLED'}
    def reconcile(self, dispatch_key):
        rid = self.by_key.get(dispatch_key)
        return {'dispatchKey': dispatch_key, 'remoteId': rid} if rid else None
