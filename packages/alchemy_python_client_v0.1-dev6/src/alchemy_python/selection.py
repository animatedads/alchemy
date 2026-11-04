"""Port for an application-provided Alchemy Connect Selector adapter.

ConnectSelector v0.1-dev1 is now published and the exact native adapter is
available in native_selector.py. This legacy narrow injection port remains
for independent service hosts, with no local selection logic or retries.
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Any, Literal, Protocol
from .errors import ContractError
from .services import ServiceContract, Operation

@dataclass(frozen=True)
class Invocation:
    """Published service intent, not an RPC envelope, job or native object."""
    service: str
    api_version: str
    operation: str
    kind: Literal['request', 'notification']
    semantics: Literal['immediate', 'job']
    params: list[Any] | dict[str, Any] | None

    def __post_init__(self):
        if not all(isinstance(s, str) and s for s in (self.service, self.api_version, self.operation)):
            raise ContractError('service, version and operation are required')
        if self.kind not in ('request', 'notification') or self.semantics not in ('immediate', 'job'):
            raise ContractError('unknown invocation kind/semantics')
        if self.kind == 'notification' and self.semantics == 'job':
            raise ContractError('durable jobs require acknowledged request')
        if self.params is not None and not isinstance(self.params, (list, dict)):
            raise TypeError('service params must be list, dict or None')

class ConnectSelectorPort(Protocol):
    """SDK adapter shape, NOT a claim about native Connect Selector methods."""
    def request(self, invocation: Invocation) -> Any: ...
    def notify(self, invocation: Invocation) -> None: ...

class SelectorClient:
    """Adapts published operations; leaves selection to the injected authority."""
    def __init__(self, selector: ConnectSelectorPort):
        if not callable(getattr(selector, 'request', None)) or not callable(getattr(selector, 'notify', None)):
            raise TypeError('selector adapter needs request() and notify()')
        self.selector = selector

    def _intent(self, contract: ServiceContract, op: Operation, params):
        if op not in contract.operations:
            raise ContractError('operation not published in this contract')
        return Invocation(contract.name, contract.api_version, op.rpc_method,
                          op.kind, op.semantics, params)

    def invoke_service(self, contract: ServiceContract, op: Operation, params=None):
        if op.kind != 'request':
            raise ContractError('cannot request a notification')
        return self.selector.request(self._intent(contract, op, params))

    def notify_service(self, contract: ServiceContract, op: Operation, params=None) -> None:
        if op.kind != 'notification':
            raise ContractError('cannot notify a request')
        self.selector.notify(self._intent(contract, op, params))
        # No delivery/remote completion acknowledgement is inferred.
        return None
