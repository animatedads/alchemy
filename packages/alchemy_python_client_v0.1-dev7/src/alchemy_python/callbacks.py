"""Bounded in-process callback sink for RpcServiceCore/0.1 method invocation.

RPC Service Core requires onNext(value), onComplete([status]), onFault(fault),
and isCancelled(). These Python-named methods are for an explicitly qualified
native proxy projection. This is NOT a network streaming or gRPC transport.
"""
from __future__ import annotations

from dataclasses import dataclass
from threading import Lock
from typing import Any

from .errors import ContractError


@dataclass(frozen=True)
class CallbackSnapshot:
    """One consistent observation of a local callback lifecycle."""
    events: tuple[Any, ...]
    completed: bool
    cancelled: bool
    status: Any
    fault: Any


class LocalRpcCallbackSink:
    """Retains bounded local events; exposes exact ooRexx sink method names.

    No automatic trust of a remote invocation, no registration of these
    methods as remotely callable RPC operations, and no transport guarantees.
    The caller must qualify actual native proxy method projection/casing.
    """

    def __init__(self, *, max_events: int = 1024) -> None:
        if type(max_events) is not int or max_events <= 0:
            raise ValueError("max_events must be a positive integer")
        self._max_events = max_events
        self._lock = Lock()
        self._events: list[Any] = []
        self._completed = False
        self._cancelled = False
        self._status: Any = None
        self._fault: Any = None
        self._terminal = False

    def onNext(self, value: Any) -> None:
        with self._lock:
            if self._terminal or self._cancelled:
                raise ContractError("callback sink is terminal or cancelled")
            if len(self._events) >= self._max_events:
                self._cancelled = True
                raise ContractError("local callback buffer full; producer must stop")
            self._events.append(value)

    def onComplete(self, status: Any = None) -> None:
        with self._lock:
            if self._terminal or self._cancelled:
                raise ContractError("callback already terminated or cancelled")
            self._completed = True
            self._terminal = True
            self._status = status

    def onFault(self, fault: Any) -> None:
        with self._lock:
            if self._terminal:
                raise ContractError("callback already terminal")
            self._fault = fault
            self._terminal = True

    def isCancelled(self) -> bool:
        with self._lock:
            return self._cancelled

    def cancel(self) -> None:
        with self._lock:
            self._cancelled = True

    def snapshot(self) -> CallbackSnapshot:
        with self._lock:
            return CallbackSnapshot(tuple(self._events), self._completed,
                                    self._cancelled, self._status, self._fault)
