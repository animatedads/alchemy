# ooRexx BOSH / API Client Adapter v0.1-dev1

Optional adapter from generic BOSH `BoshHttpExchangeProvider` to the portfolio ooRexx API Client v0.4 API.

This package exists so BOSH remains a protocol-neutral logical-stream package. BOSH owns RID/SID sequencing and XEP-0124 body semantics. API Client owns HTTP/HTTPS framing, redirect policy, TLS identity verification, route/session selection and admission. The adapter only converts:

```text
BoshHttpExchangeProvider~exchange(uri, method, headers, body)
   -> ApiRequest
   -> ApiClient~execute
   -> BoshHttpResponse
```

The adapter does **not** import XMPP, XEP-0206, SocketProvider or XTP. It does not infer transport security from application state and it does not grant Messaging/Presence authority.

By default cleartext `http://` targets are refused; callers must explicitly construct the adapter with `allowCleartext=.true` for a controlled test/deployment policy.

## Current lower-transport boundary

API Client v0.4.1 currently documents native socket ownership as RxSock. Therefore this adapter provides a real generic HTTP/HTTPS authority for BOSH, but it does **not** by itself qualify HTTPS-over-XTP. That composition remains a lower API Client/selector transport-backend task. BOSH and this adapter must not grow XTP-specific code to close it.

## Qualification status

dev1 includes deterministic shape/policy tests with a fake API Client. No live network, TLS, redirect, HTTP/2 or XTP claim is made by this package.


## Current source authorities

Checked 2026-10-27 against current GitHub source:

- BOSH transport `0.1-dev6`, semantic API `bosh.transport/0.1`.
- API Client `0.4.1`, semantic API `api.client/0.4`.

The current `ApiRequest` constructor accepts the exact method, URL, headers object, body, traffic policy fields, metadata object, `ApiRouteRequirement` object and origin node used by this adapter. The current `ApiResponse` exposes status/body plus headers, HTTP version, final URL, redirect count, egress node and session identity used by the reverse projection.

The adapter deliberately preserves rich objects at the ooRexx boundary: it does not serialize the request headers or route requirement merely to cross from BOSH to API Client. Response headers likewise remain an ooRexx object in `BoshHttpResponse~metadata`.

This source candidate was rebased onto current `main` on 2026-10-27 before qualification continuation.
