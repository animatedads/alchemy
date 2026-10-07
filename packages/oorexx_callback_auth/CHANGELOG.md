# Changelog

## 0.1-dev1

- First provider-neutral callback authentication development cut.
- OIDC authorization-code + PKCE client and provider roles.
- Exact redirect, state, nonce and one-time code enforcement.
- HS256 and RS256 JWT lanes.
- JWK Set parsing and `kid` selection.
- API Client discovery/JWKS/token adapters.
- HTTP-neutral provider endpoint projection.
- RFC 6238 TOTP SHA-1/SHA-256/SHA-512.
- `otpauth://` enrolment and QR-decoder seam.
- usable-lifetime TOTP selection and replay guard.
