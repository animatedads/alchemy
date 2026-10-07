# MAS/MAIL pre17 integration boundary

Library input reviewed: `mvs_alchemy_services_v0.1-dev3-pre17-wire-typed-locked.zip`.

The pre17 host qualification provider exposes `MasMemorySmtpProvider~submit(draft)` and the
current gateway fills `signaturePresent`, `signatureVerified`, `identityMatches`,
`emailSendAuthorized`, and `egressPermitted` from wire values before calling it.  Those fields
are useful fixture inputs, but they are **not** acceptable production authority evidence.

SMTP dev7 therefore provides `SmtpMasMailProvider` with two deliberately different entry points:

```text
submit(draft)
    -> MAS_PRINCIPAL_REQUIRED

submitFor(hostPrincipalId, sessionId, draft)
    -> construct SmtpSession + SmtpMessage
    -> verify signature from actual RFC822/MIME bytes
    -> bind signer to host-attributed principal
    -> ask Access Permissions for EMAIL_SEND
    -> run current egress policy + required model lane
    -> durable spool only if all gates pass
```

A production MAS gateway must obtain `hostPrincipalId` from the host identity/authentication
boundary.  MVS userid, MAS session id, transport address, TLS, or a guest boolean does not by
itself establish SMTP principal authority.

## MAILSIGN

`MAILSIGN` maps to optional `SmtpMasMessageSigner~sign(...)`.  Private-key custody remains in the
host signing authority.  The guest receives signed message bytes/evidence, not the private key.
A successful signing request does **not** grant `EMAIL_SEND`; `MAILSEND` re-verifies the message
and re-runs release authority.

## Required pre17 gateway change for production use

Replace the qualification pattern:

```text
guest VERIFIED/AUTHORIZED/EGRESS -> draft flags -> smtpProvider~submit(draft)
```

with:

```text
host session attribution -> principalId
MAILSIGN -> smtpProvider~signFor(principalId, draft)        [optional]
MAILSEND -> smtpProvider~submitFor(principalId, sessionId, draft)
```

The existing bounded MAS wire operation range `1400-14FF`, handle model and BYTES treatment of
RFC822/MIME material remain compatible.  This SMTP package does not claim to modify or requalify
the MVS guest transport itself.
