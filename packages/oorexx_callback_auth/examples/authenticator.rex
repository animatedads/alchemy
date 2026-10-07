/* Deterministic example. In an application, nowSeconds comes from trusted time. */
uri="otpauth://totp/Example:alice%40example.com?algorithm=SHA1&digits=6&issuer=Example&period=30&secret=JBSWY3DPEHPK3PXP"
enrollment=.AuthenticatorEnrollment~fromUri(uri,"example")
vault=.InMemoryAuthenticatorVault~new
auth=.Authenticator~new(vault)
ignore=auth~enroll(enrollment)
nowSeconds=.AuthClock~unixNow
code=auth~codeWhenUsable("example",nowSeconds,12)
say code~value
say "valid from" code~validFrom "until" code~validUntil "(" code~remainingSeconds "seconds at observation time)"
::requires "CallbackAuth.cls"
