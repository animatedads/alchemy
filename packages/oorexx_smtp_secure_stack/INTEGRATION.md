# Integration notes

## LDAP / Identity

Construct the existing LDAP `PlainLdapSaslProvider` over the platform's authenticator/Secret Broker path and inject it into `LdapSmtpAuthenticator`. SMTP AUTH forwards PLAIN credential bytes to that provider only after TLS.

## Access / Permissions

`EMAIL_SEND` is the explicit outbound send action. The SMTP relay path fails closed when no authority is configured or when the authority denies/unavailable.

`AccessPermissionsSmtpAuthorityV1` is the concrete bridge. It creates `AccessControlRequest(requestId, principalId, "SMTP:MAIL", action, intendedAt)`, adds SMTP/message/signature evidence attributes, seals the request, and delegates to `AccessControlAuthority~decide(request, policy)`. This mirrors the qualified LDAP dev10 adapter contract.

## Message signatures

`OpenSslSmimeMessageSignatureVerifier` is the first concrete profile. It verifies S/MIME/CMS against a configured CA/system trust path, extracts signer RFC822/email identity and certificate SHA-256 fingerprint, and returns `SmtpMessageSignatureEvidence`. SMTP never takes custody of user private keys. Other profiles can implement the same verifier contract.

## Storage Fabric

A `SmtpDeliveryProvider` should persist message bytes and policy metadata through Storage Fabric references. `deliverLocal(..., mailbox)` receives either `INBOX` or `INBOX-UNSIGNED`. Quarantine must remain distinct from either mailbox.

## Queue / Comms

`relaySigned()` should publish a durable outbound-delivery job with the verified signature evidence and policy decision provenance. Retry/backoff/bounce generation belong to the delivery worker, not the synchronous ingress association.

## Observation / provenance

Project `smtp.event/0.1` events to the normal observation/journal/provenance path. Important events include ingress accepted/denied, mailbox route, egress denied, egress relayed, authentication result, policy result, model result and quarantine reference.

## Storage Fabric / QueueRexx (dev4)

Use `StorageFabricSmtpStore` with the application's authoritative `StorageCatalogue`. Its durable location is marked verified only after byte-for-byte readback of the committed RFC822 object. Extended attributes preserve SMTP purpose, sender principal, envelope and inspection/signature provenance.

Use `StorageFabricSmtpDeliveryProvider` as the `SmtpDeliveryProvider`. Supply the local-domain set and, optionally, an `SmtpQueueRexxPublisher`.

The QueueRexx publisher follows the same optional binding style as Storage Fabric's QueueRexx integration and emits persistent `smtp.relay.request/1` references in security domain `SMTP.RELAY/1`.

## Outbound dispatcher

Consume `smtp.relay.request/1` as a durable work notification only. Use its `spool_id` to load
the authoritative spool record and Storage Fabric object, then invoke `SmtpOutboundDispatcher`.
Do not treat QueueRexx delivery, retry count, or a previous policy receipt as `EMAIL_SEND`
authority. Dispatcher results persist recipient-level delivery/defer/failure state and bounce
evidence. Queue scheduling may use that state to request a later retry.

## Socket Provider v0.1-dev13

Instantiate `SmtpPlatformSocketConnector` with the estate `SocketProvider` and pass it as the
second argument to `RxSockStartTlsSmtpRelayTransport`.  The relay transport then obtains TCP via
`SocketProvider~senderAt()` before performing SMTP STARTTLS through the configured secure-socket
client provider.

## MVS Alchemy pre17

Use `SmtpMasMailProvider~submitFor(principalId, sessionId, draft)`.  Do not map guest
`VERIFIED`, `AUTHORIZED`, or `EGRESS` fields to SMTP authority.  See `MVS_PRE17_INTEGRATION.md`.
