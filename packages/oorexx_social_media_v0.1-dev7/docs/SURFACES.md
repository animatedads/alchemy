# Social Surfaces: CMS brand-builder contract (dev2)

A **surface** is `(providerId, family, resourceId, visibility)`. A provider such as Steam can host more than one kind of interaction. A reference adds `(itemKind, itemId)`; all correlation uses qualified identities, not ambiguous comment IDs, channel names, or URLs.

## Family examples

- Steam: `gaming.community` discussions/announcements, `gaming.review` player review and developer response, `gaming.workshop` creator assets/comments/subscriptions.
- Discord: `chat.community` guild-channel messages, threads, roles, reactions and moderation; `chat.direct` private messaging (different authority and consent).
- YouTube: `video.comments` top-level comments and threaded replies; `video.creator` posts/memberships/creator participation; `video.live` live chat. Creator memberships are never inferred from comment authorship.
- Amazon/eBay: `marketplace.product` product questions, answers, reviews, seller messages; `marketplace.seller` seller feedback/reputation. Order, fulfilment and payments remain in commerce services.
- Google Business Profile: `local.business` location-specific reviews and business replies.
- Email groups/forums: `email.group` subscriptions/digests/unsubscribe; `forum` votes, threads and moderation.
- Sponsored placements: `social.advertising` creative, placement and measurement. Separate explicit financial authorisation and provider agreement are mandatory.

The family catalog is a *semantic vocabulary*, not an API availability or rights list. Real adapter discovery must supply read/write/response/analytics rights, account scopes, moderation roles, quotas, region-specific restrictions and policy details at runtime. A profile admitting `reply` **does not** give CMS authority to reply.

## Inbound contract

`SocialInteraction` carries an origin-specific event id and source, a qualified target, optional parent and content, plus extensible metadata. `SocialInboundGate` denies all events without a verifier, verifies source **before** recording, deduplicates by provider/surface/source/event ID and keeps independent child edges. A parent may arrive after its replies, or never arrive due to restricted visibility. The prototype retains accepted events in memory only. Production must use durable idempotency, journaled offsets, content classification and time-bounded replay prevention; callback/webhook signatures and permissions depend on the provider.

## CMS creative intent

`SocialCreativeVariant` preserves a variant's angle, intended audience, content, asset refs and lineage. The original is not silently overwritten to fit channel-specific styles or restrictions. `SocialPaidPlacementPlan` expresses an account, ceiling in minor currency units and an approval reference. It cannot book or spend; approval reference presence is *not proof* of approval.

## Integration boundaries

Intention Service owns goals, chosen angles and audience strategy. Messaging & Presence/SMTP/IMAP own transport. API Client and Socket Provider own HTTP and network. Queue Fabric owns durable commands/retries. Media/Storage services own media objects and derivatives. Institutional Policy owns actor/account/consent/financial permissions. Observation/Instrumentation receive redacted metrics and outcomes. Commerce owns orders and payments. Review-reply and advertising APIs are separate adapters with their own provider-specific rules.

## Planned production increments

1. Inbound event signing adapters + durable replay journal, redaction, opt-in/suppression, moderation and deletion propagation.
2. Per-surface adapter implementations with observable capability negotiation; provider-specific API contract tests and conformance suites, without unauthorised scraping.
3. CMS intention-to-creative/placement planning, permissioned human/automated approval, omnichannel engagement analytics and observational attribution.

## Creator, moderator and community roles

`SocialParticipation` records an actor's observed relationship to an exactly scoped surface (`creator`, `member`, `moderator`, `developer`, etc.), its status, and mandatory evidence reference. `SocialParticipationIndex` isolates those observations by actor, surface and role. These records are **not credentials or entitlements**: a platform-authoritative adapter must check current scope and role before performing any operation. Consent, sponsorship disclosures and relationship history should be retained through the estate's normal policy/provenance services.
