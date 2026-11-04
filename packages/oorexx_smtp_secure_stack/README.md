# ooRexx SMTP Secure Stack v0.1-dev7.4

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


## v0.1-dev7.1 — post-DATA cleanup hotfix

Once a next-hop server has returned a definitive final DATA reply, QUIT and close are cleanup only. They now run behind a local syntax-exception boundary so cleanup failures cannot replace a known 2xx/4xx/5xx recipient result with a generic retryable transport failure. `tests/review_cleanup_exception.rex` covers both QUIT and close exceptions after final `250`.

LDAP integration contract is aligned to PR #71: active attributed IdentityDirectory principal plus explicit `MAIL_READ` / `EMAIL_SEND`; Bind or signing alone never implies `EMAIL_SEND`.


## v0.1-dev7.2 — restart-safe mail storage

The local-delivery storage path is hardened for service restart and IMAP handoff:

- RFC822 message bytes remain write/readback verified before commit.
- SMTP envelope/session metadata is now written to a temporary file, read back, and atomically moved into place. A metadata failure makes the delivery fail rather than returning a false durable success.
- Storage Catalogue persistence is checkpointed through a temporary file and committed only after a non-empty checkpoint exists.
- Mailbox membership writes are idempotent, preventing replay/retry from duplicating a message in a mailbox projection.
- `mailboxObjectIds()`, `mailboxCount()` and `loadMailboxMessage()` expose a bounded storage-facing mailbox projection for IMAP/mail-service consumers without duplicating message bodies.
- `tests/test_mail_store_restart.rex` reconstructs a new Storage Catalogue and SMTP store from disk and verifies mailbox enumeration plus byte-identical message reload after restart.

This is a source-level readiness increment. Autobuilder is not currently running, so no fresh live-host qualification is claimed by this commit.


## v0.1-dev7.3 — fail-closed recovery validation

Restart recovery now rejects orphaned or inconsistent storage state. `loadMessage()` requires a recovered Storage Catalogue object, checks the RFC822 file size against catalogue evidence, rejects short reads, and requires complete envelope metadata. The restart regression covers orphan-body and missing-metadata failure paths.


## v0.1-dev7.4 — inbound MX service and shared IMAP mailbox projection

This increment makes the current restart-safe store consumable as an actual inbound mail service. `bin/rasenfalcon_smtp_inbound_service.rex` and `rasenfalcon-smtp-inbound.service` compose the owned SMTP wire server, OpenSSL secure-socket provider and Storage Fabric local-delivery store for configured local domains. The inbound profile deliberately does not provide authenticated relay.

Mixed local+relay transactions are rejected before any local storage side effect, preventing a later relay denial from turning an already-written local message into a retry ambiguity. `ImapSmtpDeliveredMailboxProvider` exposes `INBOX` and `INBOX-UNSIGNED` as a read-side projection over the same membership/object store; it reads the exact stored RFC822 object rather than creating a second mailbox body.

Internet MX ingress does not require LDAP authentication. Authenticated submission and IMAP user access remain separate services and must use an active attributed IdentityDirectory principal plus explicit `MAIL_READ` / `EMAIL_SEND` authority; Bind or signing alone grants neither.
