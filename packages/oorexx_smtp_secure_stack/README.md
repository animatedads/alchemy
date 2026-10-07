# ooRexx SMTP Secure Stack v0.1-dev7

SMTP server and reusable secure-socket/TLS layer for Open Object Rexx 5.3.0 r13196, integrated with the existing identity, access-control, cryptographic-signature, Storage Fabric, QueueRexx/Queue Fabric, policy, ML/LLM and audit boundaries.

## Non-negotiable mail rules

Outbound relay is permitted only when all of these are true:

1. the message itself carries a verified user-bound signature;
2. the verified signer identity matches the authenticated SMTP principal;
3. the platform access authority grants `EMAIL_SEND`;
4. egress deterministic policy inspection permits release;
5. configured ML/LLM advisory inspection permits release when that lane is required.

Authentication alone never grants relay. SMTP never adds a user signature merely to make an unsigned message relayable.

Inbound routing remains deliberately simple:

- verified signed inbound -> `INBOX`
- unsigned or invalid-signature inbound -> `INBOX-UNSIGNED`

Either path can still be rejected or quarantined by ingress policy.

## dev4

Dev4 adds durable mail delivery and outbound-spool composition.

`StorageFabricSmtpStore` stores message bytes once as a Storage Fabric object and records verified durable location evidence after byte-for-byte readback. Mailbox, quarantine and outbound-spool state are projections over that object rather than duplicate message bodies.

`StorageFabricSmtpDeliveryProvider` classifies local/relay recipients, projects local delivery into `INBOX` or `INBOX-UNSIGNED`, records quarantine membership, and turns permitted relay into a durable outbound spool item.

`SmtpQueueRexxPublisher` is an optional thin QueueRexx/Queue Fabric adapter. It publishes only durable spool/object references using persistent queue messages bound to security domain `SMTP.RELAY/1`. QueueRexx retains queue, ACL, channel, transport and peer authority.

Audit/event projection now includes signature, deterministic-policy, model-advisory, mailbox, Storage Fabric object and spool evidence.

## Secure socket

`secure.socket/0.1` is provider neutral. The OpenSSL implementation uses RxSock for TCP and Foreign Runtime v0.22.6 for OpenSSL calls through memory BIOs. TLS policy is kept below SMTP protocol semantics.

Dev4 upgraded the secure-socket implementation qualification from compile-only native evidence to a live STARTTLS handshake on the supplied runtime/Foreign Runtime stack. Dev7 additionally binds outbound TCP acquisition to the estate Socket Provider v0.1-dev13 contract while retaining SMTP-owned STARTTLS sequencing.

## Anti-abuse / ML / LLM

Ingress and egress are separately inspected. Signature status is projected before inspection so spam/phishing/abuse classifiers can use verified/unsigned/invalid evidence. Models remain advisory inputs; deterministic policy remains the enforcement authority. A configured required model lane fails closed when unavailable.

## APIs

- `smtp.server/0.1`
- `smtp.policy/0.1`
- `smtp.event/0.1`
- `smtp.durable.delivery/0.1`
- `secure.socket/0.1`
- Queue request schema: `smtp.relay.request/1`

See `VALIDATION.txt`, `ARCHITECTURE.md`, `INTEGRATION.md`, `SECURITY.md`, and `SOURCE_PROVENANCE.md`.

### dev5

Adds executable outbound release/dispatch and retry semantics. The dispatcher revalidates the
message signature, `EMAIL_SEND`, and egress inspection immediately before network transmission;
uses recipient-level durable state to avoid duplicate delivery on partial retry; persists 4xx
deferral and 5xx bounce evidence; and includes a live-qualified RxSock + Foreign Runtime +
OpenSSL STARTTLS client path with certificate/hostname verification.

## v0.1-dev6 — reviewed SMTP protocol hardening

Dev6 validates and repairs the three SMTP findings from the 2026-09-27 portfolio review rather than accepting them on inspection alone. Failed durable journal writes are now observable and authoritative transition results are checked; a post-DATA QUIT failure cannot turn an accepted `250` into a retry; reply framing is bounded and EOF/guard ordering fails safely. See `REVIEW_FIXES_DEV6.md`.


## v0.1-dev7 — current Socket Provider + MAS/MAIL integration

Dev7 rebases the integration edge against the current Library state on 2026-10-07.

- `SmtpPlatformSocketConnector` acquires outbound TCP endpoints through Socket Provider v0.1-dev13 `SocketProvider~senderAt()` / `SocketAddresses~tcp()`. SMTP no longer needs to own native TCP acquisition when the platform provider is supplied.
- STARTTLS remains an SMTP protocol transition: after the remote `220`, the existing secure.socket/OpenSSL provider upgrades the provider-acquired raw stream in place. A live SocketProvider -> STARTTLS -> DATA qualification is included.
- The signed-user-message relay rule is now a stack invariant. `SmtpPolicyConfig~requireVerifiedUserSignatureForRelay` is a read-only compatibility getter that always returns true; there is no setter/override path.
- `SmtpMasMailProvider` is the MAS/MAIL host binding. `submit(draft)` deliberately fails with `MAS_PRINCIPAL_REQUIRED`; the secure path is `submitFor(hostPrincipal, sessionId, draft)`, which reconstructs the message and re-enters the normal signature, `EMAIL_SEND`, deterministic-policy and model inspection gates. Guest-provided `VERIFIED`, `AUTHORIZED` and `EGRESS` booleans are not authority.
- `MAILSIGN` is represented as an optional host `SmtpMasMessageSigner`. Signing never grants send authority, and `MAILSEND` always re-verifies the resulting message.
- LDAP/Identity v0.1-dev14 is the current identity-directory line; SMTP continues to consume its SASL attribution contract rather than copying LDAP identity semantics.

See `MVS_PRE17_INTEGRATION.md` and `VALIDATION.txt`.
