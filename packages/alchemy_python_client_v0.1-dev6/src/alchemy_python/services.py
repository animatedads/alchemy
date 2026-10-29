"""Published-service operation authority independent of all connector choices."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Literal, Mapping, TYPE_CHECKING

from .errors import ContractError
from .rpc import JsonRpcClient
if TYPE_CHECKING:
    from .selection import SelectorClient


@dataclass(frozen=True)
class Operation:
    python_name: str
    rpc_method: str
    kind: Literal["request", "notification"] = "request"
    semantics: Literal["immediate", "job"] = "immediate"

    def __post_init__(self) -> None:
        if not self.python_name.isidentifier() or self.python_name.startswith("_"):
            raise ContractError("operation Python name must be a public identifier")
        if not self.rpc_method or not isinstance(self.rpc_method, str) or self.rpc_method.startswith("rpc."):
            raise ContractError("invalid published RPC method")
        if self.kind not in ("request", "notification") or self.semantics not in ("immediate", "job"):
            raise ContractError("invalid operation kind or semantic type")
        if self.kind == "notification" and self.semantics == "job":
            raise ContractError("job submission requires an acknowledged request, not notification")


@dataclass(frozen=True)
class ServiceContract:
    name: str
    api_version: str
    operations: tuple[Operation, ...]

    def __post_init__(self) -> None:
        if not self.name or not self.api_version:
            raise ContractError("service identity/version required")
        names = [op.python_name for op in self.operations]
        if len(names) != len(set(names)) or any(x in ("call", "notify", "contract", "_client") for x in names):
            raise ContractError("duplicate or reserved Python method name")
        wires = [op.rpc_method for op in self.operations]
        if len(wires) != len(set(wires)):
            raise ContractError("duplicate published RPC method")

    @classmethod
    def from_manifest(cls, doc: Mapping[str, Any]) -> "ServiceContract":
        if doc.get("schema") != "alchemy.python.service-contract.v1":
            raise ContractError("unknown service contract schema")
        ops = doc.get("operations")
        if not isinstance(ops, list):
            raise ContractError("operations must be a list")
        return cls(str(doc["name"]), str(doc["api_version"]), tuple(Operation(
            python_name=op["python_name"], rpc_method=op["rpc_method"],
            kind=op.get("kind", "request"), semantics=op.get("semantics", "immediate")
        ) for op in ops))


class ServiceProxy:
    """A published service proxy, never a live ooRexx object handle."""

    def __init__(self, client: JsonRpcClient | SelectorClient, contract: ServiceContract) -> None:
        self._client = client
        self.contract = contract

    def call(self, rpc_method: str, params: list | dict | None = None) -> Any:
        op = next((o for o in self.contract.operations if o.rpc_method == rpc_method
                   and o.kind == "request"), None)
        if op is None:
            raise ContractError(f"method not published for service {self.contract.name}: {rpc_method}")
        if hasattr(self._client, "invoke_service"):
            return self._client.invoke_service(self.contract, op, params)
        return self._client.request(rpc_method, params)

    def notify(self, rpc_method: str, params: list | dict | None = None) -> None:
        op = next((o for o in self.contract.operations if o.rpc_method == rpc_method
                   and o.kind == "notification"), None)
        if op is None:
            raise ContractError(f"notification not published for service {self.contract.name}: {rpc_method}")
        if hasattr(self._client, "notify_service"):
            self._client.notify_service(self.contract, op, params)
        else:
            self._client.notify(rpc_method, params)

    def __getattr__(self, name: str):
        for op in self.contract.operations:
            if op.python_name == name:
                if op.kind == "request":
                    return lambda params=None, _name=op.rpc_method: self.call(_name, params)
                return lambda params=None, _name=op.rpc_method: self.notify(_name, params)
        raise AttributeError(name)


class AlchemySession:
    """One service binding; connector choice may belong to Connect Selector."""

    def __init__(self, client: JsonRpcClient | SelectorClient) -> None:
        self.client = client

    def service(self, contract: ServiceContract) -> ServiceProxy:
        return ServiceProxy(self.client, contract)
