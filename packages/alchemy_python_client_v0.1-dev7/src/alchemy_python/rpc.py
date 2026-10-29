"""Strict Python JSON-RPC 2.0 client; does not import Queue Fabric or ooRexx."""
from __future__ import annotations

import json
import math
import uuid
from typing import Any, Protocol

from .errors import ProtocolError, RemoteError

DEFAULT_MAX_BYTES = 1024 * 1024


class Transport(Protocol):
    """Exchange one JSON document, or emit a notification without a reply."""

    def exchange(self, request: bytes) -> bytes: ...
    def send(self, notification: bytes) -> None: ...


def _check_json(value: Any, depth: int = 0, *, max_depth: int = 48) -> None:
    """Reject ambiguous/nonportable values before sending a command."""
    if depth > max_depth:
        raise ValueError("JSON maximum nesting exceeded")
    if value is None or isinstance(value, (str, bool)):
        return
    if isinstance(value, int):
        # Safe interoperable integers across JSON implementations; use strings for larger IDs.
        if not -(2**53 - 1) <= value <= (2**53 - 1):
            raise ValueError("integer outside interoperable JSON safe-integer range; encode as a string")
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError("NaN/infinity is not valid interoperable JSON")
        return
    if isinstance(value, list):
        for element in value:
            _check_json(element, depth + 1, max_depth=max_depth)
        return
    if isinstance(value, dict):
        for key, element in value.items():
            if not isinstance(key, str):
                raise ValueError("JSON object keys must be strings")
            _check_json(element, depth + 1, max_depth=max_depth)
        return
    raise TypeError(f"not a JSON value: {type(value).__name__}")


def _no_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise ProtocolError("duplicate JSON object member")
        out[key] = value
    return out


def _reject_constant(constant: str) -> None:
    raise ProtocolError(f"non-JSON numeric constant: {constant}")


class JsonRpcClient:
    """No retries and no transparent switch to a Queue Fabric adapter.

    Transport failures after sending a mutating call are ambiguous; never replay
    them automatically. Service idempotency is a separate authority contract.
    """

    def __init__(self, transport: Transport, *, max_bytes: int = DEFAULT_MAX_BYTES) -> None:
        if not isinstance(max_bytes, int) or max_bytes < 128:
            raise ValueError("max_bytes must be >= 128")
        self.transport = transport
        self.max_bytes = max_bytes

    def _encode(self, obj: dict[str, Any]) -> bytes:
        _check_json(obj)
        result = json.dumps(obj, separators=(",", ":"), ensure_ascii=True, allow_nan=False).encode("utf-8")
        if len(result) > self.max_bytes:
            raise ProtocolError("outbound JSON document exceeds byte limit")
        return result

    def request(self, method: str, params: list[Any] | dict[str, Any] | None = None) -> Any:
        self._validate_method_params(method, params)
        request_id = uuid.uuid4().hex
        frame: dict[str, Any] = {"jsonrpc": "2.0", "method": method, "id": request_id}
        if params is not None:
            frame["params"] = params
        response_bytes = self.transport.exchange(self._encode(frame))
        if not isinstance(response_bytes, bytes):
            raise ProtocolError("transport did not return response bytes")
        if len(response_bytes) > self.max_bytes:
            raise ProtocolError("inbound JSON document exceeds byte limit")
        try:
            doc = json.loads(response_bytes.decode("utf-8"), object_pairs_hook=_no_duplicate_pairs,
                             parse_constant=_reject_constant)
        except (UnicodeError, ValueError) as exc:
            raise ProtocolError("invalid JSON response") from exc
        if not isinstance(doc, dict) or doc.get("jsonrpc") != "2.0":
            raise ProtocolError("invalid JSON-RPC response envelope")
        if type(doc.get("id")) is not str or doc["id"] != request_id:
            raise ProtocolError("JSON-RPC response id mismatch")
        if ("result" in doc) == ("error" in doc):
            raise ProtocolError("response must contain exactly one of result and error")
        if "error" in doc:
            error = doc["error"]
            if not isinstance(error, dict) or type(error.get("code")) is not int or not isinstance(error.get("message"), str):
                raise ProtocolError("invalid JSON-RPC error object")
            raise RemoteError(error["code"], error["message"], error.get("data"))
        return doc["result"]

    def notify(self, method: str, params: list[Any] | dict[str, Any] | None = None) -> None:
        """Send once; no reply or delivery confirmation is implied."""
        self._validate_method_params(method, params)
        frame: dict[str, Any] = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            frame["params"] = params
        self.transport.send(self._encode(frame))

    @staticmethod
    def _validate_method_params(method: str, params: object) -> None:
        if not isinstance(method, str) or not method or method.startswith("rpc."):
            raise ValueError("method must be a nonempty published non-reserved name")
        if params is not None and not isinstance(params, (dict, list)):
            raise TypeError("JSON-RPC params must be a JSON object or array")
