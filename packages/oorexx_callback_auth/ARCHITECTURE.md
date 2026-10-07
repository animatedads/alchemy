# Architecture

The package separates protocol roles rather than treating "SSO" as one object.

```text
                   Identity / login authority
                            |
                            v
                      OidcProvider
                      /     |     \
              client reg   codes   JWT signer
                  |          |          |
             secret refs     |      key authority
                             |
HTTP server  <---- OidcProviderHttpAdapter

browser/user agent
       |
       v
   OidcClient ---- OidcTokenTransport ---- API Client / HTTPS
       |                                      |
 transaction state                       external IdP
 state / nonce / PKCE                         |
       |                                discovery + JWKS
       +---------- JwtAuthority <-------------+

Authenticator
   |
   +-- OtpAuthUri
   +-- TotpCredential
   +-- TotpGenerator / Verifier
   +-- ReplayGuard
   `-- QR decoder provider seam
```

Key boundaries:

1. HTTP servers own sockets, TLS listeners and request parsing. Provider objects own OIDC semantics.
2. API Client owns outbound HTTP/TLS. Callback Auth maps OIDC payloads only.
3. Secret Broker/secret providers own credential custody. Callback Auth keeps references where possible.
4. Crypto owns digest/RSA primitives. The sibling `crypto.auth/0.1` extension adds the missing SHA-1/HMAC profiles required by TOTP and HS256 composition.
5. The identity directory owns users. OIDC Provider receives an authenticated subject; it is not a private account database.
6. Authenticator QR support is semantic: image/camera code decodes a QR to an `otpauth` URI, then the authenticator imports it.
