# Qualification status

Source candidate: v0.1-dev1.

Included deterministic qualification:

- HTTPS URI is projected to an `ApiRequest` and executed through the injected `ApiClient`.
- HTTP method, URI, body and caller headers are preserved.
- `ApiResponse` status/body plus HTTP version, final URL, redirect count, egress/session evidence and headers are projected to `BoshHttpResponse`.
- cleartext HTTP is denied by default and requires an explicit adapter construction policy to allow it;
- unsupported schemes are rejected before API Client dispatch.

Not claimed:

- live HTTP or HTTPS execution;
- TLS certificate/hostname qualification by this adapter (API Client owns it);
- redirect or HTTP/2 runtime qualification by this adapter;
- SocketProvider integration;
- XTP carriage or HTTPS-over-XTP.

The adapter must be runtime-tested with ooRexx 5.3.0 and exact BOSH/API Client source roots before release.


## 2026-10-27 source reconciliation

Rebased onto current `main` before continuing qualification.

Static/source checks performed after the rebase:

- PASS package JSON parses.
- PASS exact dependency JSON parses and names BOSH dev6 / API Client v0.4.1.
- PASS current `ApiRequest` constructor accepts every field projected by the adapter.
- PASS current `ApiResponse` exposes every field projected back to BOSH.
- PASS adapter `::requires` contains only `BoshTransport.cls` and `ApiClient.cls`.
- PASS no XMPP, SocketProvider or XTP `::requires` dependency.
- PASS branch is ahead of current `main` and no longer behind it at the reconciliation checkpoint.
- PASS source contract preserves rich request headers / route requirement and response headers as ooRexx objects; no serialization/flattening bridge was introduced.
- Added executable identity assertions for the request headers object, `ApiRouteRequirement` object and response headers object.
- Added bounded `API_CLIENT_NO_RESPONSE` regression coverage.
- Qualification runner now fails closed on missing `rexx`, `rexxc`, BOSH source or API Client source, prints the runtime identity, compiles `BoshApiClientAdapter.cls`, then executes the deterministic suite.

Runtime status remains **pending** until the deterministic test is executed under ooRexx 5.3.0 r13196 (or a deliberately accepted compatible 5.3 runtime). No live HTTPS or HTTPS-over-XTP claim is added by these static checks.
