# Dynamic Story v0.1-dev3 — runtime narrative selection core

**Status: source candidate, not production admitted.** Transport-neutral ooRexx; intended to run on ooRexx 5.3.0 r13196. dev2 fixes the dev1 self-approval and stale authority design. Runtime qualification must be re-run against exact ooRexx r13196; this working container does not have the interpreter.

Run at the package root: `rexx tests/smoke.rex`.

## What is implemented

- Explicit `StoryContext(tenant,country,channel,locale,requestId)` and versioned `StoryIntention`/`StoryNarrative` candidates.
- Multiple scoped narrative variants for one intention, with deterministic ranking. Equal-priority collisions fail closed rather than depend on registration order.
- A fresh `authorityGateway~review(context,intention,narrative)` per decision. No engine-owned `approveClaim` or `revokeClaim` methods; they are not permissions a narrative renderer may grant itself.
- `StoryAuthorityResult` carries policy revision, opaque proof reference, intention/narrative revision binding, status ALLOW/DENY/HOLD/STALE; only a matching ALLOW returns actual content.
- `decideLive(context)` calls `intentionSource~candidates(context)` every time instead of caching a fixed intention list.
- One result Directory (schema `alchemy.dynamic_story.decision.v1`) for direct invocation and connector-neutral projection. No transport is embedded.

`StoryIntention` represents a narrative preference within the application; it is **not** an Intention Service `READY`/COMMIT decision, nor a permission to dispatch or publish. A production gateway MUST independently validate Intention Service activation, Brand approval, current operative Institutional Policy, claim evidence, Communications Management permission/consent and hold/retraction state before returning ALLOW.

**Trust model:** A `StoryAuthorityResult` is merely a message shape, not a signature or capability token. `setAuthorityGateway` must be supplied only by a privileged application host with independently authenticated authority connections. The mock gateway in `tests/smoke.rex` is never production approval. Treat any external Brand Narrative Directive handoff as `NO_DISPATCH`, including `READY_FOR_EXTERNAL_AUTHORITY_REVIEW`. Its editorial snapshot is not permission to communicate.

## Current upstream contracts checked 2026-10-24

- `packages/oorexx_intention_service/README.md` identifies Intention Service **v0.1-dev11**, with dynamic provider discovery and READY-gated dispatch.
- `packages/brand_narrative_directive_v0.1-dev4` remains `brand.narrative.directive/0.1`, `NO_DISPATCH`, `publicationAuthority=NONE`. Communications Discovery **dev14** is an editorial evidence-review boundary requiring request-fresh external assessment.
- `packages/institutional_policy_v0.8` operates fixed, reviewable, versioned artefacts and controls publication/deployment; runtime LLM output cannot create policy authority.
- `packages/oorexx_connect_selector_v0.1-dev6` provides a transport design and JMS typed disposition work, but its GitHub subtree is **not** a complete standalone source admission; no transport binding is claimed here.
- `packages/alchemy_website_publisher_v0.3` is candidate editorial source and native snapshot handoff, not an approved live CMS publication service.

## Next implementation gates

- Bind a privileged gateway to real current Brand/Communications/Policy/Intention Service object APIs, including tenant and session identity verification; fail closed when stale or unavailable.
- Provide context-bound decision authority evidence and a bounded revocation consistency protocol; test delayed event fanout and cross-process restarts.
- Wire an approved CMS/Wire UI projection, direct RPC and Queue Fabric adapters against their accepted interfaces, without making queues compulsory for synchronous decisions.
- Add session transition semantics, language variants, claim expiry, legal/compliance scoping, consent enforcement, LLM-safe projection, audit with privacy-minimisation and actual ooRexx runtime + strict standards qualification.

See `docs/ARCHITECTURE.md` and sphere `spheres/dynamic_story_gopher_sphere_v0.1` for the authority map, provenance and tests.

## dev3 request-bound review and LLM candidate

This version extends the host review response with exact tenant, request, country, channel, locale, reviewed claim array and operative policy-selection reference. Mismatches block and never emit narrative content. This is a deliberate breaking constructor contract from dev2. The agent projection omits request identity and proof references; it does not grant send/publication authority. Real host review, consent and retraction remains external and must be verified fresh on each request. Rasen Falcon lane: `dynamic_story` as CHATGPT.

Static source inspection only; executable regression on ooRexx r13196 remains pending.
