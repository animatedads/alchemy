"""Explicit local protocol, transport and remote application error channels."""
from __future__ import annotations


class AlchemyError(Exception):
    """Common base class for SDK failures, never an implicit successful reply."""


class ProtocolError(AlchemyError):
    """JSON-RPC protocol violation or mismatched response."""


class TransportError(AlchemyError):
    """Failure to exchange a complete message (outcome may be unknown)."""


class ContractError(AlchemyError):
    """Requested operation is absent or violates a locally pinned contract."""


class NativeBridgeUnavailable(AlchemyError):
    """Optional in-process ooRexx bridge has not been configured."""


class RemoteError(AlchemyError):
    """JSON-RPC error returned by the remote endpoint."""

    def __init__(self, code: int, message: str, data: object = None) -> None:
        self.code = code
        self.message = message
        self.data = data
        super().__init__(f"JSON-RPC {code}: {message}")
