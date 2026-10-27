# Dynamic Story architecture / 0.1-dev3

## Pipeline

Approved content catalogue / Brand Builder -> story candidates (untrusted for dispatch).
Dynamic Intention Service recognition -> `StoryIntention` candidates (recognition != authority).
Context + catalogue candidates -> deterministic scope and priority selection.
Selected intention + narrative + live context -> privileged host authority gateway.
Only exact-version, non-stale `ALLOW` with policy revision + proof reference -> narrative decision.
Channel-specific renderer / LLM projection uses the decision, never approval semantics.

## Independently owned authorities

- **Intention Service 0.1-dev11:** proposal, clarification, READY/COMMIT dispatch. Dynamic Story only consumes authoritatively resolved narrative candidates; it does not implement a second intention state machine.
- **Brand Narrative Directive 0.1-dev4:** NON-EXECUTING Brand governance/evidence projection. `NO_DISPATCH`, `publicationAuthority=NONE` even if handoff stage says external review ready.
- **Communications Discovery dev14:** request-fresh evidence review, not claim authorization. HOLD, retraction, conflicts or obsolete terminal revisions must prevent release until separately resolved.
- **Institutional Policy 0.8:** operative fixed artefact selection and jurisdiction/channel/tenant policy deployment. Authority depends on host validation, not `StoryAuthorityResult` construction.
- **Communications Management / CMS Brand Builder:** approved asset identity, claims, audience consent, campaign scope, publication and transport permissions; exact production package contracts not obtained in this review.
- **ConnectSelector 0.1-dev6:** candidate transport integration; direct/RPC/queue options are *optional* adapters, not inherited permission.

## Fail-closed states

`BLOCKED_NO_AUTHORITY`, `BLOCKED_INVALID_AUTHORITY`, `BLOCKED_MISSING_AUTHORITY_PROOF`, `BLOCKED_AUTHORITY_REVISION_MISMATCH`, `BLOCKED_DENY`, `BLOCKED_HOLD`, `BLOCKED_STALE`, `BLOCKED_AMBIGUOUS_*`. Never emit headline/body/action in blocked decisions.

## Gaps

The host must supply a trusted gateway and revalidate current claim list, freshness, authorisation and consent on *each* decision. In-process demo fixtures do not establish authentication, legal permission, publication, signed proof, transport delivery, or user identity. Revocation across live estate remains unimplemented. The service cannot be used for customer publication before those bindings pass qualification.

## dev3 request binding
The host review reply is validated against tenant, request ID, country, channel,
locale, policy selection ref, intention ID/revision, narrative ID/revision and
the complete ordered claim ID Array. All inconsistencies fail closed. This is
defence in depth only: a privileged host must verify approvals and current
withdrawals, not merely copy request attributes into the result. A selected
narrative still carries publication_authority NONE and dispatch_authority NONE.

StoryAgentProjection produces candidate LLM narrative context without request
identifier or authority proof; it is not send/publish approval. The adapter
requires a reviewed source and must be revalidated before effectful delivery.
