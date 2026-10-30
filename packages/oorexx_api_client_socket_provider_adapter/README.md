# ooRexx API Client / SocketProvider Adapter v0.1-dev3

Optional carrier adapter for API Client HTTPS transport.

API Client continues to own HTTP/1.1, HTTP/2, redirects, TLS identity, ALPN and response semantics. SocketProvider continues to own native transport acquisition. This adapter only connects those two existing boundaries.

The API Client core exposes an optional `ApiSocketConnector` constructor seam to `ApiHttpsTransport`. The default connector is `ApiRxSockConnector`, preserving v0.4.1 behaviour.

`ApiSocketProviderConnector` accepts an injected route resolver. The resolver returns the exact current `SocketAddress` selected by the lower routing / Intention authority; this package does not choose TCP, XTP, Unix or any other family.

The selected stream is wrapped in the minimal socket-shaped carrier required by the existing memory-BIO TLS session: send, recv, readiness/progress and close.

## Fail-closed readiness rule

TLS needs bounded progress/readiness. A SocketProvider carrier is accepted only when the selected native endpoint exposes `SELECT`, `PUMP` or `POLL`. No fake readiness is invented.

## Dynamic Socket Intention route resolution

`ApiSocketIntentionRouteResolver` performs a fresh Socket Intention negotiation on every API request rather than caching a startup route.

API Client route requirements such as country, VPN, network, egress class and tags remain API Client objects and are carried unchanged in negotiation metadata. They are not reinterpreted as socket-family choices.

The lower Socket request is intentionally:

```text
role             SENDER
requireStream    true
requireSecure    false
requireMulticast false
allowedSchemes   xtp, tcp
```

`requireSecure=false` is deliberate. API Client owns TLS above the selected byte carrier, so selecting a lower TLS socket would create TLS-inside-TLS. The resolver asks for a raw stream carrier and lets Socket negotiation choose among currently available raw stream providers.

The semantic socket logical name comes from `ApiRequest~metadata["socketLogicalName"]` when supplied. An injected logical-name resolver may override the mapping. URL host is only the bounded fallback for ordinary public HTTPS calls.

## dev3 — exact selected-route admission

Some estate services need more than generic stream capability. For example, a deployment may require that the selected lower route has been independently attested, or that a named service is already authenticated/encrypted below HTTPS.

dev3 adds an optional `ApiSocketRouteAdmissionPolicy` after dynamic negotiation and before `SocketProvider~streamSenderAt`. The policy receives the exact selected `SocketAddress`, `ApiUrl`, `ApiRequest`, session and `SocketNegotiationSelection`. Rejection returns no route and therefore fails closed before native acquisition.

`ApiSocketRequiredMetadataPolicy` is a generic exact-metadata implementation. Deployment supplies required keys and values; lower routing/security authority supplies the address metadata. The adapter does not define what keys such as route attestation, XTP protection, LDAP identity or private-CA channel state mean.

This preserves the authority split:

- Socket Intention discovers/selects currently feasible carriers.
- Deployment security authority attests route facts.
- The optional admission policy checks those exact facts.
- SocketProvider acquires the approved address.
- API Client performs private-CA TLS above the raw carrier.

No caller-provided request boolean is treated as security evidence.

## XTP boundary

This package creates the architectural route by which API Client HTTPS can run over an XTP-selected byte stream, but dev3 still does **not** claim live HTTPS-over-XTP. Current XTP dev34 supplies per-service protection with LDAP Identity Directory / Secret Broker key sources below this boundary; live composition must still be executed against an exact current stream.

No BOSH or XMPP dependency exists here.
