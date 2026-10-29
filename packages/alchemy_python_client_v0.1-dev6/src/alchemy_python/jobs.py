"""Durable-job *service contract consumer*, not a Queue Fabric transport implementation."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .errors import ContractError
from .services import ServiceProxy


@dataclass(frozen=True)
class JobReceipt:
    """Only produced for an explicit, accepted submission *as claimed by the service*.

    Server-side admission truth must be backed by the configured durable job
    provider; the Python SDK cannot prove that independently.
    """

    job_id: str
    state: str
    correlation_id: str | None

    @classmethod
    def parse(cls, reply: Any) -> "JobReceipt":
        if not isinstance(reply, dict) or reply.get("accepted") is not True:
            raise ContractError("service did not return an accepted-job receipt")
        job_id = reply.get("job_id")
        state = reply.get("state")
        correlation = reply.get("correlation_id")
        if type(job_id) is not str or not job_id or type(state) is not str or not state:
            raise ContractError("invalid accepted-job receipt fields")
        if correlation is not None and type(correlation) is not str:
            raise ContractError("invalid job correlation id")
        return cls(job_id, state, correlation)


class JobServiceClient:
    """Explicit request/reply facade for a *published* durable-job service.

    This does not create a Queue Fabric gateway. Servers must enforce the
    idempotency key and map accepted job operations to their real provider.
    """

    def __init__(self, service: ServiceProxy, *, submit_method: str = "jobs.submit",
                 status_method: str = "jobs.status", result_method: str = "jobs.result",
                 cancel_method: str = "jobs.cancel") -> None:
        self.service = service
        self.methods = {"submit": submit_method, "status": status_method,
                        "result": result_method, "cancel": cancel_method}
        published = {op.rpc_method for op in service.contract.operations if op.kind == "request"}
        if not set(self.methods.values()) <= published:
            raise ContractError("durable job operations must be explicitly published as requests")

    def submit(self, payload: dict[str, Any], *, idempotency_key: str) -> JobReceipt:
        if not isinstance(payload, dict):
            raise TypeError("job payload must be JSON object")
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            raise ContractError("idempotency key is required for durable mutation")
        result = self.service.call(self.methods["submit"],
                                   {"payload": payload, "idempotency_key": idempotency_key})
        return JobReceipt.parse(result)

    @staticmethod
    def _job_id(job_id: str) -> dict[str, str]:
        if not isinstance(job_id, str) or not job_id:
            raise ContractError("job_id must be nonempty string")
        return {"job_id": job_id}

    def status(self, job_id: str) -> dict[str, Any]:
        result = self.service.call(self.methods["status"], self._job_id(job_id))
        if not isinstance(result, dict):
            raise ContractError("job status must be a JSON object")
        return result

    def result(self, job_id: str) -> Any:
        return self.service.call(self.methods["result"], self._job_id(job_id))

    def cancel(self, job_id: str, *, idempotency_key: str) -> Any:
        if not isinstance(idempotency_key, str) or not idempotency_key.strip():
            raise ContractError("idempotency key required for cancellation request")
        return self.service.call(self.methods["cancel"],
                                 {**self._job_id(job_id), "idempotency_key": idempotency_key})
