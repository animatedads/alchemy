# Social Media v0.1-dev5 — scoped publication admission

Contract: `social.media.scoped-publication/0.1` (development).
Base: exact v0.1-dev4 distribution files, plus `SocialScopedPublication.cls` and new regression.

## Why this exists

An API saying `publish=true` is insufficient. Steam developers may respond to reviews for one app but not another; a Discord bot can post in one channel but lack permissions elsewhere; YouTube comments and creator membership actions have different capabilities; marketplace responses can be limited to one seller account and product. Provider-wide declarations do not establish a scoped right to act.

## API

- `SocialScopedCapability~new(providerId,accountId,surfaceKey,action,revision,evidence,active,maxBodyBytes,maxAssets)` is an immutable capability observation. `revision` and `evidence` identify the observation; **neither grants authority**.
- `SocialScopedCapabilityResolver~resolve(request)` is an abstract SPI. A live implementation MUST consult the relevant account/surface authorization source and fail closed on revoked, stale, ambiguous or inaccessible capabilities. The resolver is invoked afresh on each previously unseen request. It must ensure whatever freshness TTL and revocation rules the underlying provider requires; this package cannot do that by itself.
- `SocialScopedCapabilityGate~check(request)` verifies exact provider/account/surface/operation scope and byte/media-count restrictions. It does not authorize a publication.
- `SocialScopedPublicationService~new(library,journal=.nil,resolver=.nil)` wraps dev4 `SocialPublicationService`, preserves its explicit `authority` property, and interposes the capability check before the first outbox checkpoint. `submit`, `lookup` and `reconcile` retain the dev4 semantics. No public accessor to the unguarded inner dispatcher is exported by this facade.
- `SocialTestScopedResolver` is a **test fixture only**; it cannot verify current permissions, control remote account credentials or establish vendor authenticity. `SocialDenyScopedResolver` is the default.

## The dispatch sequence

1. Application constructs immutable **publication intent inputs** (CMS content revision, approved claim references, brand, account, surface, action, narrative and parent for replies).
2. Scoped resolver must produce a *current* exact account/surface capability observation for a new request. Any `nil`, inactive, missing or mismatched observation fails closed **before outbox preparation or remote invocation**.
3. The inner dev4 service checks its independent `SocialPublicationAuthority` (approval validity, organisation, principal, jurisdiction etc.), its provider-wide capability and `SocialLibrary` institutional policy.
4. Optional journal writes `prepared` and `dispatching` before provider invocation. Uncertain outcomes enter `unknown` and await verified reconciliation; no blind retry.
5. Replay of an already recorded request returns the existing receipt with full fingerprint collision protection and causes **no new provider dispatch** even if the capability has since been revoked. Revocation prevents new publications, not historical observation.

`SocialScopedPublicationService` must be the only route exposed to a live application: direct use of dev4 `SocialPublicationService` lacks the new scope check. This library does **not** implement a secure sandbox against a malicious in-process caller.

## Boundaries to reuse, not duplicate

| Estate authority | Responsibility | Social Media interaction |
| --- | --- | --- |
| CMS Brand Builder | Owned content/assets/claims/approvals | Stable revision and approval refs |
| Dynamic Story | Runtime narrative decision | Stable narrative/intention refs, reevaluate when needed |
| Communications Management / Messaging & Presence | Conversations, channels, messaging semantics | Optional adapters rather than replacement routing |
| Institutional Policy and identity services | Approval validity and principal/account entitlements | Inject `SocialPublicationAuthority` and scoped resolver |
| API Client / Secret Broker | HTTP/client mechanics, credentials | Future platform adapters only |
| Storage Fabric / pointed journal | Production durability and concurrency authority | Implement `SocialPublicationJournal` SPI; **do not use the development file journal for production** |
| Connect Selector / RPC / Queue Fabric | Selectable interconnect | Transport-neutral social semantic API |
| Brand Interaction Effect and Instrumentation Mesh | Measured outcomes/provenance | Detached event/receipt projection, never invented effect |

## Explicit non-goals and qualifications

- No API sessions, OAuth handling, live platform network calls, media uploads, marketplace transaction actions, ad spend or buying ChatGPT ads.
- `maxBodyBytes` is a transport-byte ceiling, not a grapheme/Unicode character limit; platform-specific transformations require additional adapter validation. `maxAssets` is count only, not MIME/type/aspect ratio validation.
- `active=true` means *observed capability permitted* and is not user consent or a posting mandate. Policy/approval remain independent.
- A provider can revoke a capability between preflight and remote execution; a live provider adapter must still handle its own rejection safely and return accurate evidence.
- The inherited dev4 journal is process-restart-oriented and single-writer, **not** fsync-backed, multi-writer fenced or production durable. No exactly-once remote delivery guarantee.
- Unknown runtime qualification must not be converted to PASS: use the bundled `tests/run_all.sh` against an actual ooRexx interpreter.
