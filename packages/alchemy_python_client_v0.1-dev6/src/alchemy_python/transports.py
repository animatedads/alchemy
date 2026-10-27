"""Safe opt-in transports; stdio demo is not an authenticated remote service."""
from __future__ import annotations

import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Sequence
from typing import Any

from .errors import ProtocolError, TransportError
from .rpc import DEFAULT_MAX_BYTES


class CallableTransport:
    """Injectable transport for application hosts and tests."""

    def __init__(self, exchange: Callable[[bytes], bytes], send: Callable[[bytes], None]) -> None:
        self._exchange = exchange
        self._send = send

    def exchange(self, request: bytes) -> bytes:
        return self._exchange(request)

    def send(self, notification: bytes) -> None:
        self._send(notification)


class SubprocessTransport:
    """One JSON-RPC newline frame per fresh subprocess, with a hard timeout.

    Works with the existing JsonRpcFabric examples/stdio_server.rex. Intentionally
    not a pooling/persistent transport; restart overhead is the cost of a robust,
    cross-platform first slice. Uses argv, never shell command interpolation.
    """

    def __init__(self, argv: Sequence[str], *, timeout: float = 10.0,
                 env: dict[str, str] | None = None, max_bytes: int = DEFAULT_MAX_BYTES) -> None:
        if not argv or any(not isinstance(s, str) or not s for s in argv):
            raise ValueError("argv must be a non-empty sequence of command strings")
        if timeout <= 0 or max_bytes < 128:
            raise ValueError("invalid timeout/byte bound")
        self.argv = tuple(argv)
        self.timeout = timeout
        self.env = env
        self.max_bytes = max_bytes

    def _run(self, frame: bytes, *, expects_response: bool) -> bytes:
        if b"\n" in frame or b"\r" in frame:
            raise ProtocolError("raw newlines are not allowed in a stdio frame")
        if len(frame) > self.max_bytes:
            raise ProtocolError("request exceeds byte bound")
        # Redirect child output into files, not unbounded in-memory pipes. The
        # child is still resource-limited by its deadline, not a hardened sandbox.
        try:
            with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
                proc = subprocess.Popen(self.argv, stdin=subprocess.PIPE,
                                        stdout=out, stderr=err, env=self.env, shell=False)
                try:
                    proc.communicate(frame + b"\n", timeout=self.timeout)
                except subprocess.TimeoutExpired as exc:
                    proc.kill()
                    proc.communicate()
                    raise TransportError("stdio server timed out; operation outcome unknown") from exc
                out.seek(0)
                err.seek(0)
                stdout = out.read(self.max_bytes + 1)
                stderr = err.read(self.max_bytes + 1)
        except OSError as exc:
            raise TransportError("could not start stdio server") from exc
        if len(stdout) > self.max_bytes or len(stderr) > self.max_bytes:
            raise ProtocolError("stdio output exceeded configured response limit")
        if proc.returncode != 0:
            raise TransportError(f"stdio server failed with exit status {proc.returncode}")
        if not expects_response:
            if stdout.strip():
                raise ProtocolError("notification elicited unexpected server output")
            return b""
        lines = stdout.splitlines()
        if len(lines) != 1 or not lines[0]:
            raise ProtocolError("stdio server must emit exactly one response frame")
        return lines[0]

    def exchange(self, request: bytes) -> bytes:
        return self._run(request, expects_response=True)

    def send(self, notification: bytes) -> None:
        self._run(notification, expects_response=False)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """RPC authority must not change via implicit HTTP redirects."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class HttpTransport:
    """JSON-RPC over HTTP POST client for a separately qualified gateway endpoint.

    HTTP(S) *client* support does not mean an Alchemy HTTP JSON-RPC server exists.
    Plain HTTP is forbidden except for explicit development-loopback opt-in.
    """

    def __init__(self, url: str, *, token: str | None = None, timeout: float = 10,
                 max_bytes: int = DEFAULT_MAX_BYTES, allow_insecure_loopback: bool = False,
                 opener: Callable[..., Any] | None = None) -> None:
        parsed = urllib.parse.urlsplit(url)
        if parsed.username or parsed.password or parsed.fragment:
            raise ValueError("URL must not embed credentials or fragments")
        if parsed.scheme != "https":
            loopback = parsed.scheme == "http" and parsed.hostname in ("localhost", "127.0.0.1", "::1")
            if not (allow_insecure_loopback and loopback):
                raise ValueError("HTTPS required; explicit loopback exception for development only")
        if not parsed.netloc or timeout <= 0 or max_bytes < 128:
            raise ValueError("invalid endpoint or resource bound")
        if token is not None and (not token or "\r" in token or "\n" in token):
            raise ValueError("invalid bearer token")
        if token is not None and parsed.scheme != "https":
            raise ValueError("bearer token requires HTTPS even on loopback")
        self.url = url
        self.token = token
        self.timeout = timeout
        self.max_bytes = max_bytes
        self.opener = opener or urllib.request.build_opener(_NoRedirect()).open

    def _post(self, frame: bytes, expects_response: bool) -> bytes:
        if len(frame) > self.max_bytes:
            raise ProtocolError("outbound JSON document exceeds byte limit")
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        if self.token is not None:
            headers["Authorization"] = "Bearer " + self.token
        request = urllib.request.Request(self.url, data=frame, headers=headers, method="POST")
        try:
            with self.opener(request, timeout=self.timeout) as response:
                status = response.status
                content_type = response.headers.get("Content-Type", "").lower()
                if status < 200 or status >= 300:
                    raise TransportError(f"HTTP status {status}; outcome may be unknown")
                data = response.read(self.max_bytes + 1)
                if len(data) > self.max_bytes:
                    raise ProtocolError("inbound JSON document exceeds byte limit")
                if expects_response:
                    if "application/json" not in content_type:
                        raise ProtocolError("HTTP RPC response has non-JSON content type")
                    if not data:
                        raise ProtocolError("empty HTTP RPC response")
                else:
                    if data.strip():
                        raise ProtocolError("JSON-RPC notification must not return a JSON document")
                return data
        except (urllib.error.URLError, OSError) as exc:
            raise TransportError("HTTP exchange failed; outcome may be unknown") from exc

    def exchange(self, request: bytes) -> bytes:
        return self._post(request, expects_response=True)

    def send(self, notification: bytes) -> None:
        self._post(notification, expects_response=False)
