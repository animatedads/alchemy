# MAS/MAIL personality — pre4 binding contract

MAS/MAIL is a deliberately small MVS 3.8j mail programming personality.  It does
not implement SMTP, IMAP, TLS, MIME, SASL, OAuth or private-key custody in the
S/370 guest.  Those responsibilities remain with the ooRexx mail services.

Wire operation range: `1400-14FF`.

## Authoritative mail-side contracts used by this candidate

The binding is based on the current SMTP Secure Stack dev8 contract and the
current IMAP dev12 service/API evidence available to this project.

SMTP:
- message bytes are durable once, with mailbox/quarantine/outbound-spool state
  represented as projections/references;
- verified signed inbound local delivery is `INBOX`;
- unsigned or invalid-signature inbound local delivery is `INBOX-UNSIGNED`;
- outbound relay requires a verified user-bound message signature;
- signature evidence does not grant authority;
- `EMAIL_SEND` authority is independently required;
- queue presence is never network-release authority.

MAS adds **no compatibility override** for unsigned relay.  There is no
MAS option, flag, operator command, PARMLIB keyword or application bit that can
make an unsigned/invalid message relayable.

IMAP:
- stable remote identity is account + mailbox + UIDVALIDITY + UID;
- large inboxes are paged/streamed rather than materialised in MVS storage;
- body reads should use non-mutating BODY.PEEK-style semantics unless the caller
  explicitly requests a state mutation;
- message move/delete semantics must preserve the exact-UID safety boundary;
- attachment/body/header material is exposed as bounded streams.

## Initial MVS semantic calls

Inbound/read:
`MAILINIT MAILBOX MAILLIST MAILOPEN MAILENV MAILHEAD MAILBODY MAILPART
 MAILNEXT MAILSEEN MAILCLOS MAILTERM`

Outbound:
`MAILNEW MAILFROM MAILTO MAILTEXT MAILPART MAILSIGN MAILSEND MAILSTAT`

These names are MAS application semantics, not claims that identically named
classes exist in the ooRexx mail packages.

## Security invariant

`MAILSEND` can submit only a message for which the host mail authority reports:
1. a message signature is present;
2. the signature is cryptographically verified;
3. it is bound to the attributed sending principal;
4. that principal is authorised for `EMAIL_SEND`;
5. deterministic egress policy permits the release.

Transport authentication, MVS userid, localhost, operator privilege, IP
allowlists, queue presence and TLS never substitute for the message signature.

MAS does not take custody of a user's signing private key. `MAILSIGN` is a
semantic request to an explicitly authorised host signing capability; if no
such capability is configured, a caller must supply a message already signed
by an accepted profile.

## Representation

RFC822/MIME bytes and attachments are `BYTES`.  Text fields are explicit `CHAR`
values with negotiated conversion.  MAS must never EBCDIC-translate a MIME body
or attachment merely because the caller is MVS.

## Handles and bounded storage

Mailbox, message, body-part and outbound-draft objects are opaque MAS handles.
Listing and body transfer are bounded/paged.  A modern mailbox is never
materialised into the 16 MB reference MVS address space.

## Mailbox truth

MAS uses canonical mailbox names `INBOX` and `INBOX-UNSIGNED`; it does not
rename them to Signed/Unsigned.  `From:` is presentation metadata, not proof of
authorship. Verification evidence is exposed separately.

## Failure mapping

MAS retains the underlying mail diagnostic while returning a stable MAS/MAIL
result.  At minimum callers can distinguish:
- unsigned message;
- invalid signature;
- signature/principal mismatch;
- missing `EMAIL_SEND` authority;
- deterministic-policy denial;
- mailbox/session invalidation (including UIDVALIDITY change);
- transport/service unavailable;
- outcome unknown for an unconfirmed mutating request.
