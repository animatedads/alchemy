# Dev7 — guarded adapter dispatch, outbox-bound admission

## Changed contract (intentional fail-closed change)

`SocialAdapterProvider~new(adapter)` is **no longer valid**. Configure
`SocialDispatchGuard~new(publicationAuthority, scopedCapabilityResolver, dispatchPolicy, journal)`
and construct `SocialAdapterProvider~new(adapter, guard)`. Wire the **same**
`journal`, authority and policy into `SocialScopedPublicationService`.

`SocialPublicationRequest~context` carries a local-only `requestObject` for
reconstruction and exact semantic comparison at the dispatch choke point.
The adapter wrapper removes `requestObject` before invoking `SocialAdapter~dispatch`;
the existing development journal serialises only its declared scalar fields.

On dispatch the guard checks:

1. Request object exists and matches provider, operation, account, brand, surface,
   body, content version, approval/intention/narrative, parent, and media refs.
2. The external publication authority still accepts the exact request.
3. A freshly resolved provider/account/surface/action capability is active and
   the rendition fits its limits.
4. The independently supplied dispatch policy approves.
5. The shared journal already contains exactly this request's fingerprint in
   `dispatching` state. An omitted, `prepared`, `unknown`, rejected, delivered,
   or altered outbox record cannot authorise dispatch.
6. The request has not already consumed this guard's in-process dispatch right.

The guard validates the outbox using `replay(.false)` to INSPECT the active
journal without applying crash-recovery transitions. Normal `replay()` still
converts incomplete in-flight states into `unknown` on restart. This is a
backward-compatible addition to the journal replay SPI.

## Scope and remaining production blockers

* This makes the **standard registered adapter wrapper** reject low-level
  dispatch lacking authority and an outbox checkpoint, including direct
  `SocialLibrary~execute` calls. It does not sandbox arbitrary ooRexx code
  that can access raw adapter objects and call `adapter~dispatch` itself.
* `SocialFilePublicationJournal` remains SINGLE-WRITER DEVELOPMENT ONLY:
  arithmetic checksum, no fsync, no interprocess fencing, no tamper-proof
  journal. It is NOT an institutional persistence authority.
* `SocialDispatchGuard` consumes request IDs in process. Distributed exactly-
  once and crash-safe fencing require an authoritative journal/lease backend,
  queue topology and provider idempotency key verification.
* `SocialTestPublicationAuthority` / `SocialTestAdapter` are never live proofs.
  Real providers require API Client/HTTPS, Secret Broker, LDAP account binding,
  Institutional Policy and independent inbound/delivery verifiers.
* No ad purchase/spend or live moderation operation is implemented.

## Evidence

Run `bash tests/run_all.sh` against pinned ooRexx 5.3.0 r13196.
`adapter_contract.rex` now exercises deny-without-guard, low-level pre-outbox
denial even with current capability and brand approval, and duplicate denial
when a later direct call tries to redispatch. The other dev6 tests remain.
If ooRexx is missing, report NOT RUN rather than PASS.
