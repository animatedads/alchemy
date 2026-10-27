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
