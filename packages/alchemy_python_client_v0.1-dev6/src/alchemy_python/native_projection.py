"""Optional retained ooRexx-object projection for the independent Alchemy bridge.

This is an adapter to *existing* Python Macrospace RexxObject.send() behavior.
It does not load a runtime, marshal handles, flatten ooRexx objects, or claim
compatibility with the separate upstream oorexxpython/ python-for-oorexx APIs.
"""
from __future__ import annotations

from typing import Any
from .errors import ProtocolError


class RexxSelectorProjection:
    """Present ConnectSelector's published messages to NativeConnectSelectorPort.

    The supplied object MUST be a retained native RexxObject identity. The
    underlying Macrospace runtime retains responsibility for re-entry, class
    lookup, affinity and lifetime. No attribute introspection is performed.
    """

    def __init__(self, selector: Any) -> None:
        if not callable(getattr(selector, "send", None)):
            raise TypeError("a retained ooRexx projection with send() is required")
        self.native = selector

    def execute(self, intent: Any, payload: Any) -> Any:
        return self.native.send("EXECUTE", intent, payload)

    def explain(self, intent: Any) -> Any:
        return self.native.send("EXPLAIN", intent)

    def setObserver(self, observer: Any) -> Any:
        return self.native.send("SETOBSERVER", observer)


def rexx_result_field(result: Any, name: str) -> Any:
    """Read published ConnectResult getters by native Rexx message dispatch."""
    if not callable(getattr(result, "send", None)):
        raise ProtocolError("ConnectResult must retain native send() projection")
    if name not in ("ok", "provider", "accepted", "completed", "durable",
                    "value", "code", "detail"):
        raise ProtocolError("field is not part of ConnectResult/0.1")
    return result.send(name.upper())


def rexx_logical(value: Any) -> bool:
    """Explicit decoder for known Rexx logical scalar representations.

    Does NOT apply Python truthiness: '0' is false, never true. Foreign native
    logical proxies must supply a different decoder from their bridge.
    """
    if type(value) is bool:
        return value
    if type(value) is int and value in (0, 1):
        return bool(value)
    if type(value) is str and value in ("0", "1"):
        return value == "1"
    raise ProtocolError("invalid Rexx logical scalar; explicit bridge decoder required")
