# ooRexx Social Media Library — v0.1-dev7

Provider-neutral social media semantics for CMS Brand Builder / Dynamic Story:
WhatsApp/private and email communities, X, Facebook, Reddit, Steam, Discord,
YouTube creator/comment surfaces, marketplaces and business reviews.
No live vendor connector, credential, paid ad purchase or assumed platform rights.

## New in dev7

**Standard adapter dispatch is now guarded at the execution choke point**, not
only at the CMS-facing facade. `SocialDispatchGuard` binds independent brand
approval, exact account/surface/action capability, provider policy and an
outbox checkpoint already marked `dispatching` to the full publication request.
`SocialAdapterProvider` now rejects construction without this guard, and strips
the local request object before passing a payload to an adapter. The guard also
prevents duplicate dispatches in the same process. See
`docs/DEV7_DISPATCH_GUARD.md` for integration and limitations.

Unchanged: dev1–dev6 semantic content/surface/interaction APIs and simulation
facilities, per-account capabilities, inbound/verifier seams and development
outbox semantics. `SocialPublicationRequest~context` gains a LOCAL-ONLY request
reference; journal framing remains on the existing declared scalar fields.

## Qualification

`bash tests/run_all.sh` expects `rexx` 5.3.0 r13196 (REXX_PATH is set by script).
The test runner includes synthetic providers and a dev-file outbox. The
publication code and sphere have static/source-archive verification; actual
REXX execution is **NOT QUALIFIED** in environments without this interpreter.

## Live implementation requirements

* LDAP / institutional policy authority and Secret Broker account credentials;
* API Client / own HTTPS policy for authorised provider endpoints;
* Storage Fabric or durable Queue Fabric journal, single-writer ownership and
  crash-safe fencing before production outbound traffic;
* separate authenticated inbound, remote-delivery and moderation checks;
* CMS content truth and Dynamic Story versioned intention/claim references.

No compiled or third-party dependencies are vendored. Source is under `src/`.
