"""Python wire peer for ooRexx JSON-RPC Fabric 0.1-dev2/dev3 TCP framing.

This is a *protocol transport*, not a ConnectSelector routing authority.
The private profile is exactly 8 uppercase ASCII hexadecimal bytes indicating
payload octets, followed by that number of octets. Both peers must select the
same protocol; it is not HTTP or a universal JSON-RPC framing standard.

Only loopback is enabled by default because the ooRexx dev3 demo server has no
native authentication or TLS. An untrusted remote endpoint is NOT qualified.
"""
from __future__ import annotations

import ipaddress
import socket
from contextlib import closing

from .errors import ProtocolError, TransportError
from .rpc import DEFAULT_MAX_BYTES

_HEX = frozenset(b"0123456789ABCDEF")


def _read_exact(conn: socket.socket, size: int) -> bytes:
    """Bounded read handling fragmented TCP segments and premature EOF."""
    chunks = []
    remaining = size
    while remaining:
        try:
            part = conn.recv(remaining)
        except (OSError, TimeoutError) as exc:
            raise TransportError("RPC socket read failed; outcome may be unknown") from exc
        if not part:
            raise TransportError("RPC socket closed before complete frame; outcome may be unknown")
        if len(part) > remaining:
            raise ProtocolError("RPC socket returned excess bytes")
        chunks.append(part)
        remaining -= len(part)
    return b"".join(chunks)


class FramedSocketTransport:
    """One new TCP connection per JSON-RPC message, without retry or pooling.

    The client uses the private JsonRpcLengthFrame profile, as implemented by
    oorexx_json_rpc_fabric_v0.1-dev3/src/JsonRpcSocketTransport.cls. Transport
    errors do not prove that an invoked method was not executed.
    """

    PROFILE = "oorexx.json_rpc_fabric/tcp-length-hex8"

    def __init__(self, host: str, port: int, *, timeout: float = 5.0,
                 max_bytes: int = DEFAULT_MAX_BYTES,
                 allow_unauthenticated_remote: bool = False) -> None:
        if not isinstance(host, str) or not host or host.strip() != host:
            raise ValueError("host must be a non-empty, unambiguous hostname or address")
        if type(port) is not int or not 1 <= port <= 65535:
            raise ValueError("port must be an integer between 1 and 65535")
        if not isinstance(timeout, (int, float)) or isinstance(timeout, bool) or not 0 < timeout < float('inf'):
            raise ValueError("timeout must be a finite positive number")
        if type(max_bytes) is not int or not 128 <= max_bytes <= 0xFFFFFFFF:
            raise ValueError("max_bytes must be between 128 and 0xFFFFFFFF")
        if type(allow_unauthenticated_remote) is not bool:
            raise ValueError("allow_unauthenticated_remote must be Boolean")
        # Never use DNS to decide whether a string *names* loopback: ordinary
        # hostnames can be rebound. Verify the actual connected peer below.
        try:
            is_loopback = ipaddress.ip_address(host).is_loopback
        except ValueError:
            is_loopback = (host.lower() == "localhost")
        if not is_loopback and not allow_unauthenticated_remote:
            raise ValueError("raw RPC TCP is unauthenticated: only loopback is supported by default")
        self.host = host
        self.port = port
        self.timeout = float(timeout)
        self.max_bytes = max_bytes
        self._allow_remote = allow_unauthenticated_remote

    def _open(self) -> socket.socket:
        try:
            conn = socket.create_connection((self.host, self.port), timeout=self.timeout)
        except (OSError, TimeoutError) as exc:
            raise TransportError("could not connect to RPC socket; operation not sent") from exc
        if not self._allow_remote:
            try:
                peer = conn.getpeername()[0]
                if not ipaddress.ip_address(peer).is_loopback:
                    conn.close()
                    raise TransportError("RPC socket resolved to non-loopback endpoint; connection rejected")
            except (ValueError, IndexError, OSError) as exc:
                conn.close()
                raise TransportError("cannot verify RPC peer as loopback") from exc
        return conn

    def _frame(self, payload: bytes) -> bytes:
        if not isinstance(payload, bytes):
            raise TypeError("RPC socket payload must be bytes")
        size = len(payload)
        if not 0 < size <= self.max_bytes:
            raise ProtocolError("outbound RPC frame exceeds configured limit or is empty")
        return f"{size:08X}".encode("ascii") + payload

    def _write(self, conn: socket.socket, frame: bytes) -> None:
        try:
            conn.sendall(frame)
        except (OSError, TimeoutError) as exc:
            raise TransportError("RPC socket write failed; operation outcome unknown") from exc

    def exchange(self, request: bytes) -> bytes:
        frame = self._frame(request)
        with closing(self._open()) as conn:
            self._write(conn, frame)
            header = _read_exact(conn, 8)
            if any(byte not in _HEX for byte in header):
                raise ProtocolError("invalid RPC socket frame header (expected uppercase hex8)")
            declared = int(header, 16)
            if not 0 < declared <= self.max_bytes:
                raise ProtocolError("inbound RPC socket frame exceeds configured bound or is empty")
            return _read_exact(conn, declared)

    def send(self, notification: bytes) -> None:
        frame = self._frame(notification)
        with closing(self._open()) as conn:
            self._write(conn, frame)
        # Socket send completion does not prove delivery, execution or durability.
        return None
