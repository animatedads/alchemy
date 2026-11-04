"""Explicit gRPC transport for published methods; protobuf is owned by the caller.

This optional Python gRPC client is not a Connect Selector, RPC service
registry, or protocol compiler. Routes MUST be published with explicit
paths/serializers. grpcio handles HTTP/2 framing, TLS and trailers. No retries.
"""
from __future__ import annotations

from dataclasses import dataclass
import re
from threading import RLock
from typing import Any, Callable, Iterator

from .errors import ContractError

_GRPC_PATH = re.compile(r"^/[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*/[A-Za-z_][A-Za-z_0-9]*$")


@dataclass(frozen=True)
class GrpcMethod:
    operation: str
    path: str
    serialize: Callable[[Any], bytes]
    deserialize: Callable[[bytes], Any]
    streaming: bool = False

    def __post_init__(self) -> None:
        if not isinstance(self.operation, str) or not self.operation or not isinstance(self.path, str) or not _GRPC_PATH.fullmatch(self.path):
            raise ContractError('a published operation and /package.Service/Method gRPC path are required')
        if not callable(self.serialize) or not callable(self.deserialize):
            raise ContractError('explicit protobuf encoder and decoder are required')
        if type(self.streaming) is not bool:
            raise ContractError('streaming flag must be boolean')


class GrpcTransportError(RuntimeError):
    """Remote state can be uncertain even when gRPC reports an error."""
    def __init__(self, operation: str, cause: BaseException):
        self.operation = operation
        self.cause = cause
        self.code = cause.code() if callable(getattr(cause, 'code', None)) else None
        super().__init__(f'gRPC {operation} failed; prior effects may be unknown: {self.code}')


class GrpcClient:
    """One configured gRPC channel, explicit allowlisted operation registry.

    grpcio is optional. The injected channel can be grpc.secure_channel(),
    grpc.insecure_channel() for loopback tests, or a qualified transport port.
    Native Connect Selector routing is *not* replicated inside this class.
    """
    def __init__(self, channel: Any, *, max_stream_messages: int = 10000) -> None:
        if channel is None or not callable(getattr(channel, 'unary_unary', None)) or not callable(getattr(channel, 'unary_stream', None)):
            raise TypeError('gRPC channel requires unary_unary and unary_stream')
        if type(max_stream_messages) is not int or max_stream_messages < 1:
            raise ValueError('max_stream_messages must be positive')
        self._channel = channel
        self._methods: dict[str, GrpcMethod] = {}
        self._frozen = False
        self._lock = RLock()
        self._max_messages = max_stream_messages

    def register(self, definition: GrpcMethod) -> None:
        if not isinstance(definition, GrpcMethod):
            raise TypeError('GrpcMethod expected')
        with self._lock:
            if self._frozen or definition.operation in self._methods:
                raise ContractError('frozen registry or duplicate operation')
            self._methods[definition.operation] = definition

    def freeze(self) -> None:
        with self._lock:
            self._frozen = True

    def _get(self, operation: str, streaming: bool) -> GrpcMethod:
        with self._lock:
            definition = self._methods.get(operation)
        if definition is None or definition.streaming != streaming:
            raise ContractError('unpublished gRPC operation or wrong invocation shape')
        return definition

    @staticmethod
    def _timeout(timeout: float | None) -> float | None:
        if timeout is not None and (not isinstance(timeout, (int, float)) or isinstance(timeout, bool) or not 0 < timeout <= 86400):
            raise ValueError('timeout must be positive, at most 24 hours')
        return timeout

    def unary(self, operation: str, request: Any, *, timeout: float | None = 10) -> Any:
        definition = self._get(operation, False)
        deadline = self._timeout(timeout)
        call = self._channel.unary_unary(definition.path, request_serializer=definition.serialize,
                                         response_deserializer=definition.deserialize)
        try:
            return call(request, timeout=deadline)
        except Exception as exc:
            raise GrpcTransportError(operation, exc) from exc

    def stream(self, operation: str, request: Any, *, timeout: float | None = 10,
               max_messages: int | None = None) -> Iterator[Any]:
        """Incremental server stream. Final success only after iterator exhaustion.

        A late gRPC failure does NOT roll back values already yielded.
        Closing/cancelling a stream doesn't prove that the server did no work.
        """
        definition = self._get(operation, True)
        deadline = self._timeout(timeout)
        limit = self._max_messages if max_messages is None else max_messages
        if type(limit) is not int or limit < 1 or limit > self._max_messages:
            raise ValueError('max_messages outside configured limit')
        call = self._channel.unary_stream(definition.path, request_serializer=definition.serialize,
                                          response_deserializer=definition.deserialize)(request, timeout=deadline)

        def consume():
            count = 0
            try:
                for item in call:
                    count += 1
                    if count > limit:
                        if callable(getattr(call, 'cancel', None)):
                            call.cancel()
                        raise ContractError('gRPC server stream exceeded message bound; previous messages remain delivered')
                    yield item
            except (ContractError, GeneratorExit):
                if callable(getattr(call, 'cancel', None)):
                    call.cancel()
                raise
            except Exception as exc:
                raise GrpcTransportError(operation, exc) from exc
        return consume()

    def consume_stream(self, operation: str, request: Any, sink: Any, *, timeout: float | None = 10,
                       max_messages: int | None = None) -> int:
        """Caller-thread callback projection for an outbound gRPC stream.

        This is NOT ConnectSelector CALLBACK or the RPC Core local sink.
        Return is the number of messages; onComplete is called only after
        valid final gRPC status. A false onNext response requests cancellation.
        """
        for name in ('onNext', 'onComplete', 'onFault'):
            if not callable(getattr(sink, name, None)):
                raise ContractError('gRPC stream observer missing ' + name)
        stream = self.stream(operation, request, timeout=timeout, max_messages=max_messages)
        count = 0
        try:
            for item in stream:
                if callable(getattr(sink, 'isCancelled', None)) and sink.isCancelled():
                    stream.close()
                    raise ContractError('gRPC stream cancelled; prior effects unknown')
                count += 1
                if sink.onNext(item) is False:
                    stream.close()
                    raise ContractError('gRPC stream observer requested cancellation')
            sink.onComplete()
            return count
        except Exception as exc:
            try:
                sink.onFault(exc)
            except Exception:
                pass  # do not replace the authoritative stream failure
            raise
