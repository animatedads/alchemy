# Security invariants

- No unsigned message relays.
- No message relays merely because it is signed: `EMAIL_SEND` must also be allowed.
- The verified signer must match the attributed SMTP sender principal.
- Server TLS certificates do not count as the user's message signature.
- Authentication is not email-send authorization.
- Internal origin does not bypass egress inspection.
- External origin does not bypass ingress inspection.
- Unsigned inbound mail is not silently upgraded to trusted mail; it is routed to `INBOX-UNSIGNED`.
- Invalid-signature inbound mail is treated as unsigned for routing unless policy escalates it.
- Required ML/LLM inspection unavailable => fail closed to policy handling.
- Models advise/classify; deterministic policy owns enforcement.
- SMTP does not own user private signing keys or an independent password database.

- Signature evidence must be available to ingress/egress policy and ML/LLM inspection before those decisions execute.
- DKIM/domain signing does not satisfy the user-signature relay gate.
- S/MIME signer identity mismatch with the authenticated sender => no relay.
- Access Permissions `EMAIL_SEND` and cryptographic authorship are independent gates; neither implies the other.

## Durable/retry security (dev4)

Durability is not authority. A Storage Fabric object or QueueRexx spool entry does not itself authorize network release. Signature identity, `EMAIL_SEND`, and egress policy remain separate gates.

Message content is written once and read back before its Storage Fabric location is marked verified. Mailbox, quarantine and spool records reference that object. Queue publication is persistent and security-domain bound.

A retry/dispatcher must re-enter the egress authorization/inspection path before final transmission so policy changes, revoked send permission, or changed model requirements can stop an already-spooled item.

## dev5 release-time invariants

A durable spool item does not confer permission to transmit. Before every network dispatch:
1. the immutable stored message is reloaded;
2. its user-bound message signature is re-verified;
3. `EMAIL_SEND` is re-authorized for the attributed principal;
4. egress deterministic and configured ML/LLM policy inspection runs again;
5. the next-hop transport must satisfy its TLS policy.

Loss of authority causes HELD state and no next-hop connection. STARTTLS absence/failure does
not downgrade to plaintext. Recipient-level durable state prevents retry from re-sending a
recipient already acknowledged with a successful final SMTP response.

## dev6 delivery ambiguity rule

Once a next-hop SMTP server has returned a successful final DATA reply, QUIT is cleanup and cannot revoke that remote acceptance. Conversely, local durable recipient-state commit failure after remote acceptance is surfaced as `DELIVERY_STATE_UNCERTAIN` and must not be treated as an ordinary automatic retry condition.

## dev7 non-configurable relay signature invariant

A verified user-bound message signature is mandatory in `validateRelayRelease()` regardless of
configuration.  The former configuration property survives only as a read-only compatibility
getter returning true.  There is no supported unsigned-relay switch.

## MAS trust boundary

MVS/MAS wire values are request data, not signature/access-policy evidence.  Production MAS mail
submission must provide a host-attributed principal and then re-enter the ordinary SMTP release
gate.  MAILSIGN and MAILSEND are independent semantic operations; successful signing never
implies send authority.
