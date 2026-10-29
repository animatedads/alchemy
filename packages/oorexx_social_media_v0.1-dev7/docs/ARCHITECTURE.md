# Social Media semantic library — v0.1-dev1

## Scope

Social media is an interaction graph, not a list of vendors. The library treats direct and group messaging, federated posts, email lists, forums, video, live streams, creator relationships, comments and advertising as social communication surfaces.

## Core contracts implemented

* SocialEnvelope: identity, kind, author, body, reply relationship, target audiences, attached asset references, metadata.
* SocialCapability: named action, enabled flag, extensible constraints.
* SocialProvider: provider identity, capability discovery and dispatched operation.
* SocialLibrary: provider registry, capability validation, mandatory policy authorisation, receipt audit.
* SocialMemoryProvider: in-process **simulation only**; no outbound network or account changes.
* SocialPolicy: external authority injection; default-deny and isolated test grant implementations.

## Next adapter families (not implemented)

* Private messaging and communities: WhatsApp Business, Messenger, Signal where supported, Matrix, XMPP, Discord, Slack, Telegram.
* Feeds, forums and federation: X, Bluesky, Mastodon/ActivityPub, Facebook, Instagram, LinkedIn, Reddit, Discourse.
* Media: YouTube, TikTok, Twitch, podcasts and live events.
* Email communities and newsletters: IMAP/SMTP and opt-in list systems.
* Placement and advertising: ad accounts, creative variants, targeting restrictions, budgets, explicit financial approval, receipts, reporting. ChatGPT advertising is a potential placement category, **not** a claimed public API integration.

## Estate integration seams

Intention Service: translates user/brand objective to semantic actions and discovers supported actions each turn.
Messaging and Presence / SMTP / IMAP: delivery is delegated to existing messaging libraries, not reimplemented.
API Client + Socket Provider: authenticated provider HTTP and transport are delegated.
Queue Fabric: durable workflows, retries, schedules, idempotency and delivery outcomes.
Storage/Media: referenced assets and transcoding variants, not bytes copied into envelopes.
Identity/Policy: per-principal grants, consent, account scopes, governance, moderation, records and approval.
Instrumentation/Observation: counters and redacted events through estate provider; never expose tokens or private message text.
Structured Utterance: purpose, provenance, claims and brand voice before flattening to copy.

## Invariants for further development

1. Discovery does not imply write permission. Permission is tested again at each execution.
2. Advertising spend requires explicit financial authorisation and a bounded budget: no default purchase.
3. Inbound events require signature/authority validation, replay deduplication and provenance before publication to consumers.
4. Consent/anti-spam and audience visibility are channel-specific policy constraints.
5. Private content is private by default. Never use community conversations as an unauthorised training corpus.
6. Separate simulated acceptance from platform-live interoperability claims.
7. Track parent/reply/thread identities; distinguish authored, reported, delivered, seen, moderated, deleted and failed state.
8. Make provider rate limits, feature availability, terms and revision capabilities discoverable.
9. Treat creative/media transformations as derivatives of immutable lineage-bearing assets.
10. Attribute conversions/engagement to evidence; avoid claiming true causality from impressions alone.

## Usage

`REXX_PATH="$PWD/src" rexx tests/smoke.rex` from package root (requires ooRexx on PATH).

This dev1 foundation deliberately does not claim to implement any external vendor API.
