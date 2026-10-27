# ooRexx HTTPS Server engineering sphere v0.1

Accepted/source-truth baseline:
- canonical GitHub package currently documents v0.4.6;
- newer Library source candidate: `oorexx_https_server_v0.4.7.zip`;
- v0.4.7 Library SHA-256 `ae1a4caa1f48d6348cdfa283323a25e300bda5c30b7ea5f8ef825c635502ac3c`;
- Rasen Falcon public-site source lock independently points to this same v0.4.7 artifact.

Current continuation candidate:
- HTTPS Server v0.4.8, delivery SHA-256 `d38ddd049e5d8f5683e4ebf09e09a870c9c562bd3663db32950df711f7040fbe`;
- adds bounded request-body streaming and response-source streaming without changing RxSock/memory-BIO ownership;
- static contract qualification PASS in the 2026-10-27 ChatGPT execution environment;
- exact-r13196 runtime and live TLS qualification are pending and canonical package promotion is deliberately withheld.

This sphere is documentation/continuity, not a replacement executable package.
It inherits shared ooRexx source-navigation services from the `oorexx` sphere.

Start:

    gopher --profile https-server context https-server --full
    gopher --profile https-server search '<term>' --sphere https-server
