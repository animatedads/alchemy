# API Client v0.4 transport architecture

The authority chain remains:

provider -> ApiClient -> route/session + WLU admission -> ApiHttpsTransport -> RxSock + OpenSSL/Foreign Runtime

HTTP/2 adds libnghttp2 as the protocol codec behind a narrow native bridge. It owns HTTP/2 framing, HPACK state, stream state and SETTINGS processing; it does not own routing, DNS policy, TCP sockets, TLS trust, provider credentials, WLU policy, callbacks or completion routing.

Redirects are HTTP semantics and therefore live in ApiHttpsTransport above the HTTP/1.1 and HTTP/2 codecs. A redirect is not permission to relax egress or credential boundaries. Cross-origin redirects and HTTPS downgrade are hard-denied unless explicitly enabled. Redirect history is bounded and loop-detected.

HTTP/2 is selected only by TLS ALPN. `HTTP2_REQUIRED` fails closed when the peer does not negotiate h2. `NEGOTIATE` permits HTTP/1.1 fallback. There is no h2c prior-knowledge mode.

The v0.4 HTTP/2 path is synchronous and bounded, one request stream per transport execution. Multiplexed connection pooling is deliberately not claimed; adding pooling later must preserve per-request route/session/WLU and completion authority.
