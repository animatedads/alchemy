# Rasen Falcon public site — Dynamic Story candidate seam (dev4)

Current upstream source: `packages/rasenfalcon_delivery_v0.4.5/website/integrations/CMS_WIRE_BRIDGE.md` (checked 2026-10-29). The website remains a source/preview and site-only installation slice, not an approved running native HTTPS service. CMS Brand Builder service is not yet established as an accepted executable API. This document does not pretend to wire it up.

## Runtime sequence

1. A qualified native ooRexx service host authenticates the invoking public site/server identity and obtains the context from the request's trusted server-side facts. A country estimate is a presentation hint, not a verified identity or legal entitlement.
2. `StoryIntentionSource~candidates(context)` supplies meanings. Intention Service dev11 is the owner of recognition and confirmation; neither a search term nor an LLM label is permission to communicate.
3. `StoryCatalogueSource~snapshot(context)` returns a *new*, detached `StoryCatalogueSnapshot(revision,status,intentions,bindings)` for the particular tenant and request. An authoritative HOLD blocks the request. This source is an injection contract only; dev4 does not include a network client.
4. `StoryDecisionEngine~decideLive(context)` selects the narrative and invokes trusted `StoryAuthorityGateway~review(context,intention,narrative,catalogueRevision)`. The gateway must separately verify approved claims/assets, consent, campaign scope, live holds, and operative Institutional Policy selection for exactly that request and catalogue version. It returns an exact `StoryAuthorityResult` with the additional `catalogueRevision` argument. Reject mismatch. An in-process result object is **not** a signature.
5. `StorySiteProjection~project(decision,slotId)` returns an inert data candidate, not HTML. The host/renderer MUST escape all content; only the approved CMS/Resource Editor can publish a resource and only the Site Release service can activate it. The projection MUST NOT be treated as an approval receipt.
6. If the intent, catalog, review or connection is unavailable, show a previously independently published default static page (not an old Dynamic Story approval) or an error page. Never reuse a stale narrative to satisfy an authority failure.

## Projection fields

`schema=alchemy.dynamic_story.site_candidate.v1`, `status=BLOCKED|CANDIDATE`, `slot_id`, `narrative_id`, `narrative_revision`, `catalogue_revision`, `headline`, `body`, `action`, `claim_ids`, `publication_authority=NONE`, `dispatch_authority=NONE`.

The service does not access public SMTP, LDAP, XTP, native HTTPS, or domain deployment. Those are separate qualified owners. A future browser adapter may invoke this through authenticated ooRexx JSON-RPC, but must not expose the raw host review receipt or call a queue as an ordinary synchronous prerequisite.

## Required integration tests (not yet performed)

- A public route cannot call the host review directly or choose a tenant by arbitrary query string.
- A held/withdrawn claim invalidates the next request across all instances; stale catalogues are denied.
- Malformed catalogue/review packets do not emit headline/body/action.
- Review applies legal/jurisdictional scope, consent and exact resource hash publication independently.
- HTML escaping and Wire Site Release checks remain intact; a content candidate cannot become an active release.
