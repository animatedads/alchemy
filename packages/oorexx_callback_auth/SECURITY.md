# Security notes

Dev1 intentionally fails closed on the boundaries most commonly weakened in OAuth/OIDC glue code:

- registered redirect URI comparison is exact;
- authorization codes are one-time and expire;
- PKCE method is S256 only;
- state is compared before token exchange;
- nonce is bound into and checked from the ID token;
- issuer and audience are exact;
- expired/future ID tokens are rejected outside configured clock skew;
- JWT algorithm is explicit and verifier-specific;
- RS256 chooses keys by `kid` from an injected JWKS source;
- TOTP successful counters may be replay-fenced;
- TOTP seed material is never needed by OIDC client callback state.

The deterministic random source and in-memory credential vault are test/development helpers only.
