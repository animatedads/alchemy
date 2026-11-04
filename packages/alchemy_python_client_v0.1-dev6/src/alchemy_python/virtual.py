"""Two separate *virtual* class kinds: RPC service façade and live Rexx projection.

Neither Python wrapper inheritance nor a schema descriptor is proof of a remote
Rexx inheritance relationship; the owning runtime remains authoritative.
"""
from __future__ import annotations

from typing import Any, Callable, Mapping

from .errors import ContractError
from .services import ServiceContract, ServiceProxy


class VirtualServiceClassFactory:
    """Materialise typed-feeling Python service classes from pinned contracts.

    A virtual service is NOT a live remote object. Generation introduces no new
    RPC method names and never caches backend method targets.
    """

    @staticmethod
    def make(class_name: str, contract: ServiceContract) -> type[ServiceProxy]:
        if not class_name.isidentifier() or class_name.startswith("_"):
            raise ContractError("invalid virtual service class name")
        namespace: dict[str, Any] = {
            "__doc__": f"Virtual Alchemy service façade for {contract.name}/{contract.api_version}.",
            "__alchemy_contract__": contract,
            "__module__": __name__,
        }
        for op in contract.operations:
            if hasattr(ServiceProxy, op.python_name):
                raise ContractError("operation shadows ServiceProxy method")

            def call(self: ServiceProxy, params=None, *, _op=op):
                if _op.kind == "notification":
                    return self.notify(_op.rpc_method, params)
                return self.call(_op.rpc_method, params)
            call.__name__ = op.python_name
            call.__doc__ = f"{op.rpc_method} ({op.kind}; {op.semantics}); params: JSON array or object."
            namespace[op.python_name] = call
        return type(class_name, (ServiceProxy,), namespace)


class LiveRexxObject:
    """Wrap an object *already projected and retained* by native macrospace.

    Delegation resolves a live Python-accessible member on each call. Native
    projection controls identity, dispatch, thread safety and Rexx exceptions.
    The SDK does not mint ooRexx handles or emulate its object model.
    """

    __rexx_class_name__: str = ""
    __rexx_method_map__: Mapping[str, str] = {}

    def __init__(self, projection: Any) -> None:
        if projection is None:
            raise TypeError("live macrospace projection required")
        self._projection = projection

    @property
    def projection(self) -> Any:
        return self._projection

    def send_exact(self, rexx_name: str, *args: Any) -> Any:
        """Use the native `send` escape if supported; not a JSON-RPC message."""
        native_send = getattr(self._projection, "send", None)
        if native_send is None:
            raise ContractError("native projection has no explicit send escape")
        return native_send(rexx_name, *args)


class VirtualRexxClassFactory:
    """Build declared Python façade methods on an existing native ooRexx proxy.

    `method_map` is an explicit Python-name -> native projection member map.
    The runtime's real class/MRO identity must be queried from the bridge,
    never inferred from this wrapper's Python `__mro__`.
    """

    @staticmethod
    def make(class_name: str, method_map: Mapping[str, str]) -> type[LiveRexxObject]:
        if not class_name.isidentifier() or class_name.startswith("_"):
            raise ContractError("invalid Rexx virtual class identifier")
        namespace: dict[str, Any] = {"__rexx_class_name__": class_name,
                                     "__rexx_method_map__": dict(method_map),
                                     "__module__": __name__}
        for python_name, native_name in method_map.items():
            if not python_name.isidentifier() or python_name.startswith("_") or hasattr(LiveRexxObject, python_name):
                raise ContractError("invalid or reserved virtual Rexx method")
            if not isinstance(native_name, str) or not native_name or native_name.startswith("_"):
                raise ContractError("invalid native projection member name")

            def invoke(self: LiveRexxObject, *args: Any, _name=native_name, **kwargs: Any) -> Any:
                # Never cache a native method: the Rexx object may be amended live.
                return getattr(self._projection, _name)(*args, **kwargs)
            invoke.__name__ = python_name
            namespace[python_name] = invoke
        return type(class_name, (LiveRexxObject,), namespace)
