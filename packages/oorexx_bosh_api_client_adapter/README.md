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
