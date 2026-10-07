# API — Callback Authentication v0.1-dev1

## OIDC client

```text
OidcClientConfiguration
OidcClient
OidcLoginStart
OidcLoginTransaction
OidcCompletionResult
OidcIdentity
OidcTokenTransport
InProcessOidcTokenTransport
```

`OidcClient~beginLogin(nowSeconds)` returns an authorization URI plus the transaction object containing state, nonce, PKCE verifier/challenge and creation time.

`OidcClient~completeCallback(callbackParams, transaction, tokenTransport, nowSeconds)` validates the callback before exchanging the code and then validates the ID token.

Optional network adapters:

```text
ApiClientOidcDiscovery
ApiClientJwksSource
ApiClientOidcTokenTransport
```

These consume `oorexx_api_client_v0.4.1`; TLS and HTTP remain API Client authority.

## OIDC provider

```text
OidcProvider
OidcClientRegistration
OidcAuthorizationResult
OidcAuthorizationCodeRecord
OidcTokenResult
OidcProviderHttpAdapter
CallbackAuthHttpResponse
```

`OidcProvider~authorize(params, subject, nowSeconds)` is called only after the provider's separate authentication/session authority has established the subject.

`OidcProvider~token(params, clientAuthentication, nowSeconds)` consumes the authorization code once, verifies PKCE and issues tokens.

## JWT

```text
JwtAuthority
Hs256JwtAuthority
Rs256JwtAuthority
Rs256PrivateKeyJwtAuthority
Rs256KeyMaterial
JwksSource
StaticJwksSource
JwtVerificationResult
```

No `alg=none` path exists.

## TOTP authenticator

```text
TotpCredential
TotpGenerator
TotpCode
TotpVerifier
TotpVerificationResult
TotpReplayGuard
OtpAuthUri
AuthenticatorEnrollment
InMemoryAuthenticatorVault
Authenticator
```

`TotpGenerator~codeWhenUsable(credential, epochSeconds, minimumSeconds)` returns the current step if it has sufficient usable lifetime, otherwise the next step.

`AuthenticatorEnrollment~fromQr(input, decoder, id)` delegates QR image decoding to a supplied provider and consumes the returned `otpauth://` payload.
