# ooRexx Callback Authentication v0.1-dev1

Provider-neutral OAuth 2.0 / OpenID Connect authorization-code authentication for ooRexx, with both relying-party/client and identity-provider/server roles, plus a first-class RFC 6238 TOTP authenticator.

Public APIs:

- `callback.auth/0.1`
- `callback.auth.oidc.client/0.1`
- `callback.auth.oidc.provider/0.1`
- `callback.auth.totp/0.1`

## What dev1 implements

### OIDC client / relying party

- authorization-code flow;
- PKCE S256;
- state and nonce transaction binding;
- exact configured callback URI;
- issuer, audience, nonce, expiry and issued-at validation;
- discovery document parsing;
- HS256 JWT validation for controlled/shared-secret deployments;
- RS256 JWT verification from JWK Set material for external identity providers;
- optional `oorexx_api_client_v0.4.1` adapters for discovery, JWKS retrieval and token exchange.

### OIDC provider / SSO authority

- exact client redirect registration;
- authorization-code issuance;
- one-time authorization codes with expiry;
- PKCE S256 verification;
- client authentication through an injected secret authority;
- HS256 and RS256 ID-token signing;
- discovery metadata;
- JWKS publication for RS256;
- HTTP-neutral projection adapter for discovery, JWKS, authorize and token endpoint responses.

Authentication UI, user directory, session policy and consent UI are deliberately external. `OidcProvider~authorize()` accepts an already-authenticated subject from the authority that owns login.

### Authenticator / TOTP

- RFC 6238 SHA-1, SHA-256 and SHA-512 vectors;
- `otpauth://totp/...` import/export;
- Base32 secrets;
- configurable 6-8 digits and period;
- bounded clock-skew verification;
- replay guard;
- `codeWhenUsable(..., minimumSeconds)` so callers can avoid presenting a code about to expire;
- QR decoding as a provider seam: image decoding produces the provisioning URI; the authenticator does not own camera/image recognition.

Example:

```rexx
code = authenticator~codeWhenUsable("work", nowSeconds, 12)
say code~value
say code~remainingSeconds
```

If the current time step has fewer than 12 seconds left, the returned object describes the next TOTP step instead of presenting a nearly-expired code.

## Security boundary

No production random generator is invented here. OIDC construction requires an injected `AuthRandomSource`; the supplied deterministic source is test-only. Production deployments should bind a platform/cryptographic RNG provider.

Secrets are obtained through `AuthSecretAuthority`. `SecretBrokerAuthSecretAuthority` adapts the existing Secret Broker without making Callback Auth a secret store.

The package does not accept unsigned JWTs, does not have an "ignore state" mode, does not relax redirect URI matching, and does not silently fall back from RS256/HS256 verification.

## Current limitations

- dev1 does not implement WebAuthn/passkeys, OAuth device authorization grant, refresh-token rotation, token revocation, dynamic client registration, logout federation, SAML, SCIM or multi-issuer federation.
- RS256 private key material has an executable static key authority for qualification. Production key custody/rotation should be supplied by an external key authority rather than embedding private integers in application source.
- API Client token exchange currently implements `client_secret_post`; additional client authentication profiles (`client_secret_basic`, `private_key_jwt`, mTLS) should be separate strategies.
- TOTP in-memory vault is a development convenience. Durable seed custody belongs behind a secret-store provider.
