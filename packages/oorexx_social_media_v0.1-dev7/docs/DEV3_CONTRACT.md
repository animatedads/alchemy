# v0.1-dev3 Publication, Conversation and Brand Evidence Contract

## 1. Ownership, not duplications

CMS Brand Builder owns approved facts, claim/version lifecycle, assets and brand voice. Dynamic Story owns selection of truthful narrative appropriate to audience and interaction. Institutional Policy owns deployable rules. Identity/secret services own principal, credential, consent and rights. Social Media owns social-surface-aware interaction representation, outbound request/receipt semantics, and evidence projection. ConnectSelector, RPC, direct call or Queue Fabric may carry these requests, but none is compulsory to use this library. API Client owns external HTTP transport; Messaging and Presence owns live messaging functions. Observations/effectiveness assessments belong in the Brand/Interaction/Observation portfolio.

A producer must not infer permission from taxonomy, creator membership, participant role, account name or `approvalRef`. The actual publish-capable provider must prove permissions with account- and surface-specific capabilities at the time of dispatch.

## 2. Class summary

| Object | Purpose | Key methods |
|---|---|---|
| `SocialPublicationRequest` | Publication proposal using exact CMS/source and narrative revision | `init`, `addAsset`, `fingerprint`, `context` |
| `SocialPublicationAuthority` | Abstract institutional verification seam | `allow(request)` |
| `SocialDenyPublicationAuthority` | Default rejection | `allow(request)` |
| `SocialTestPublicationAuthority` | **Test-only** exact-request grant | `permit`, `allow` |
| `SocialPublicationService` | Preflight, one-time dispatch, receipt and reconciliation | `submit`, `lookup`, `reconcile` |
| `SocialPublicationReceipt` | Local and provider outcome evidence projection | `projection` |
| `SocialTestDeliveryVerifier` | **Test-only** synthetic remote evidence | `permit`, `verify` |
| `SocialBrandInteractionBridge` | Project already-accepted inbound interactions into detached, unevaluated brand evidence | `projectAccepted` |

`SocialPublicationRequest~init`: `id, brandId, accountId, surface, action, contentId, contentVersion, body, approvalRef, intentionRef, narrativeRef [, parent]`. `action` may only be `publish` or `reply`; a reply must point to a `SocialReference` on the same `SocialSurface`. For intentional cross-channel conversations, use separate events with explicit bridging provenance; never reuse bare remote IDs as parent links. Asset references do not imply an uploaded artifact.

## 3. The outbound state machine

```text
prepare CMS+story evidence -> verify scope, policy and provider capabilities
           | DENIED: no provider call or new outbox receipt
           v
       dispatching   [local receipt recorded before provider call]
           |
           +-- simulated        (inert memory adapter; NOT published)
           +-- rejected         (provider rejected; terminal)
           +-- submitted        (provider accepted/queued; NOT delivered)
           +-- unknown          (malformed/absent receipt or thrown dispatch)
                                     |
                      verified reconciliation -> delivered or rejected
```

`SocialPublicationService~submit` checks its own authority AND `SocialLibrary~policy` before invoking the provider. The test-only `SocialMemoryProvider` records and returns `simulated`. A duplicate request ID with byte-equivalent field/asset snapshot returns the prior receipt without dispatching again. A duplicate ID with a changed request fingerprint raises a syntax condition. A simulated receipt cannot be promoted into live delivery. A lost response or adapter exception becomes `unknown`, and repeating the same ID does not resubmit. `reconcile` requires verifier evidence of remote state; terminal outcomes cannot be overwritten.

The length-framed request fingerprint is **not** a cryptographic digest or external idempotency key. In-memory records give only single-process replay protection, not durability, thread safety or exactly-once semantics. A production adapter must use the estate's pointed journal/durable outbox, atomic claim-and-dispatch coordination, provider-native idempotency where available, signed/audited reconciliation and terminal result correction rules. Queue Fabric may provide durable delivery scheduling but does not establish the external platform's remote commit.

## 4. Evidence projections

`SocialPublicationReceipt~projection` returns a detached field directory in schema `social.outbound.receipt/0.1` with brand ID, exact CMS content ID/version, intention and narrative references, approval reference, account, surface and observed status. This is neutral evidence, *not* a Brand Interaction Effect determination.

`SocialBrandInteractionBridge~projectAccepted(interaction, gate, brandId, intentionRef)` requires that the gate has a verifier, an interaction already recorded in its graph, and an actual matching accepted audit entry. It returns `social.interaction.evidence/0.1`, with `brandEffect=not_assessed`. The projection deliberately does not claim consent, brand causation or customer sentiment. Verify/redact customer identifiers and content when exporting externally. Inbound gate verification must be production-grade; `SocialTestInboundVerifier` is explicitly synthetic.

## 5. Provider-specific capability requirements

Each platform adapter must enumerate supported operations **per account and surface**: read/listen, reply, publish, moderate, review response, community administration, upload media, observe engagement, ads placement, and billing. When unavailable, reject rather than infer. Vendor limits, scopes, approval workflows, retention, webhook credentials, paging, rate limits, deletes/edits and permission expiry must be represented in provider-specific implementations, not shoehorned into a generic `publish` promise. User-generated review responses on Amazon, Google Business Profile and Steam may differ in access and review rules. Creator features on YouTube and channel/server roles on Discord are observational until independently authorised.

For WhatsApp/email groups/private channels preserve participation and opt-in rules and do not merge independent audiences without consent. Product/catalogue, stock, orders, payment, refunds, paid ad billing and marketplace dispute arbitration belong to their authoritative commerce/financial services, not this social semantics layer.

## 6. Planned integration sequence

1. Verify delivered contracts for CMS Brand Builder, Dynamic Story, ConnectSelector, Intention Service, Messaging and Presence, Institutional Policy and Instrumentation; integrate as *optional* interfaces, not vendored source or guessed method signatures.
2. Attach authoritative live policy and account permission checks; replace test verifiers; add durable outbox and replay with injected journal/Queue Fabric and provider reconciliation.
3. Implement independent read-only vendor ingestion adapters first (Steam review and YouTube comment, subject to API capability verification), then publish/reply after scoped account authorisation; distinguish online delivery from simulated tests.
4. Add media renditions/transcoding via existing media stack, privacy/consent-scoped metric ingestion, review moderation/evidence and audience outcomes routed to Brand Interaction Effect.
