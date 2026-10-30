# API Client v0.4 transport architecture

The authority chain remains:

provider -> ApiClient -> route/session + WLU admission -> ApiHttpsTransport -> ApiSocketConnector -> byte carrier + OpenSSL/Foreign Runtime

HTTP/2 adds libnghttp2 as the protocol codec behind a narrow native bridge. It owns HTTP/2 framing, HPACK state, stream state and SETTINGS processing; it does not own routing, DNS policy, TCP sockets, TLS trust, provider credentials, WLU policy, callbacks or completion routing.

Redirects are HTTP semantics and therefore live in ApiHttpsTransport above the HTTP/1.1 and HTTP/2 codecs. A redirect is not permission to relax egress or credential boundaries. Cross-origin redirects and HTTPS downgrade are hard-denied unless explicitly enabled. Redirect history is bounded and loop-detected.

HTTP/2 is selected only by TLS ALPN. `HTTP2_REQUIRED` fails closed when the peer does not negotiate h2. `NEGOTIATE` permits HTTP/1.1 fallback. There is no h2c prior-knowledge mode.

The v0.4 HTTP/2 path is synchronous and bounded, one request stream per transport execution. Multiplexed connection pooling is deliberately not claimed; adding pooling later must preserve per-request route/session/WLU and completion authority.


## Optional socket acquisition seam

The development seam added on the `api-client-socket-provider-dev1` branch does
not move HTTP or TLS authority into SocketProvider. `ApiHttpsTransport` accepts
an optional `ApiSocketConnector`; when omitted, `ApiRxSockConnector` preserves
the v0.4.1 RxSock behaviour exactly.

A separate `oorexx_api_client_socket_provider_adapter` can acquire a selected
SocketProvider stream. Its route resolver must return the exact current
`SocketAddress` chosen by the lower routing/Intention authority. API Client
does not choose TCP/XTP/Unix/etc.

The TLS memory-BIO session still owns TLS identity, SNI, ALPN, cipher policy and
certificate verification. It consumes only send/recv/readiness/close from the
carrier.

Provider-backed carriers fail closed unless the selected native endpoint exposes
bounded readiness/progress through SELECT, PUMP or POLL. This avoids inventing
readiness for transports such as XTP.
