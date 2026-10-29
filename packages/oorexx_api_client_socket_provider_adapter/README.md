# ooRexx API Client / SocketProvider Adapter v0.1-dev2

Optional carrier adapter for API Client HTTPS transport.

API Client continues to own HTTP/1.1, HTTP/2, redirects, TLS identity, ALPN and
response semantics. SocketProvider continues to own native transport acquisition.
This adapter only connects those two existing boundaries.

The API Client core change on this branch adds an optional `ApiSocketConnector`
constructor seam to `ApiHttpsTransport`. The default connector is
`ApiRxSockConnector`, which preserves v0.4.1 behaviour.

`ApiSocketProviderConnector` accepts an injected route resolver. The resolver
must return the exact current `SocketAddress` selected by the lower routing /
Intention authority; the adapter does not choose TCP, XTP, Unix or any other
family.

The selected stream is wrapped in the minimal socket-shaped carrier required by
the existing memory-BIO TLS session: send, recv, readiness/progress and close.

## Fail-closed readiness rule

TLS needs bounded progress/readiness. A SocketProvider carrier is accepted only
when the selected native endpoint exposes `SELECT`, `PUMP` or `POLL`.
No fake readiness is invented. This is particularly important for XTP.

## XTP boundary

This package creates the architectural route by which API Client HTTPS can run
over an XTP-selected byte stream, but dev1 does **not** claim live HTTPS-over-XTP.
That requires exact current SocketProvider/XTP source plus executable runtime
qualification.

No BOSH or XMPP dependency exists here.


## dev2 — dynamic Socket Intention route resolution

`ApiSocketIntentionRouteResolver` is the standard resolver for the adapter. It performs a fresh Socket Intention negotiation on every API request rather than caching a startup route.

API Client route requirements such as country, VPN, network, egress class and tags remain API Client objects and are carried unchanged in negotiation metadata. They are not reinterpreted as socket-family choices.

The lower Socket request is intentionally:

```text
role             SENDER
requireStream    true
requireSecure    false
requireMulticast false
allowedSchemes   xtp, tcp
```

`requireSecure=false` is deliberate. API Client owns TLS above the selected byte carrier, so selecting a lower TLS socket would create TLS-inside-TLS. The resolver therefore asks for a raw stream carrier and lets Socket negotiation choose between currently available raw stream providers.

The semantic socket logical name comes from `ApiRequest~metadata["socketLogicalName"]` when supplied. An injected logical-name resolver may override the mapping. URL host is only the bounded fallback for ordinary public HTTPS calls.

Every resolve increments its generation and retains the exact `SocketNegotiationSelection` and request for evidence. No XTP selection logic is added to API Client; XTP remains one offer behind the common Socket negotiation boundary.
