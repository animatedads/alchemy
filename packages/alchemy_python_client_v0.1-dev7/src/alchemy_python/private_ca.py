"""Private-CA-only HTTPS transport for Rasen Falcon/Alchemy published services.

The Alchemy HTTPS endpoint is owned by the platform HTTPS server. This client
never invokes LDAP itself and never replaces ConnectSelector or RPC dispatch.
No ambient system CA, urllib proxy or redirect fallback is admitted.
"""
from __future__ import annotations

import os
import ssl
import urllib.request
from pathlib import Path

from .rpc import DEFAULT_MAX_BYTES
from .transports import HttpTransport, _NoRedirect


class PrivateCAHttpTransport(HttpTransport):
    """JSON-RPC HTTPS transport with *only* an explicitly provided private CA.

    Verification is mandatory (hostname + certificate chain). The TLS context is
    created from scratch, so system/ambient public CA roots are never loaded.
    Client certificates are optional but, when supplied, are used for mTLS.

    Authentication/authorization and LDAP policy are enforced by the server;
    the optional bearer token is a server-issued credential and HTTPS-only.
    """

    def __init__(self, url: str, *, ca_file: str | os.PathLike[str],
                 client_cert_file: str | os.PathLike[str] | None = None,
                 client_key_file: str | os.PathLike[str] | None = None,
                 token: str | None = None, timeout: float = 10.0,
                 max_bytes: int = DEFAULT_MAX_BYTES) -> None:
        if not isinstance(url, str) or not url.startswith('https://'):
            raise ValueError('private CA transport requires an https:// endpoint')
        if not isinstance(ca_file, (str, os.PathLike)) or not Path(ca_file).is_file():
            raise ValueError('explicit private CA certificate file is required')
        if client_key_file is not None and client_cert_file is None:
            raise ValueError('client private key requires a client certificate')
        if client_cert_file is not None and not Path(client_cert_file).is_file():
            raise ValueError('client certificate file does not exist')
        if client_key_file is not None and not Path(client_key_file).is_file():
            raise ValueError('client key file does not exist')

        # PROTOCOL_TLS_CLIENT + exact CA load, with no load_default_certs() or
        # create_default_context() call that could import a host CA fallback.
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.verify_mode = ssl.CERT_REQUIRED
        context.check_hostname = True
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.set_alpn_protocols(['http/1.1'])
        context.load_verify_locations(cafile=os.fspath(ca_file))
        if client_cert_file is not None:
            context.load_cert_chain(
                certfile=os.fspath(client_cert_file),
                keyfile=os.fspath(client_key_file) if client_key_file is not None else None)

        # Explicitly disable ambient HTTP(S)_PROXY and automatic redirects.
        opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}),
            _NoRedirect(),
            urllib.request.HTTPSHandler(context=context),
        )
        super().__init__(url, token=token, timeout=timeout,
                         max_bytes=max_bytes, opener=opener.open)
        self._private_context = context
