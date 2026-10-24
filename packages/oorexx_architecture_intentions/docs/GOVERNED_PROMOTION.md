# Governed Scenario Promotion — `architecture.promotion/0.1`

A scenario comparison is advice, not deployment permission. The promotion
boundary captures a generation of that comparison and retains the full evidence
for all alternatives before one is accepted as an architectural *design*.

## Authority and data flow

```text
Intention Service (clarified business outcome)
       |
Architecture Scenario Comparison (side-by-side, non-executable)
       |
ArchitecturePromotionReview (frozen JSON generation)
       |-- selection rationale, architect, evidence
       |-- each alternative REJECTED / DEFERRED / WITHDRAWN + why
       |-- independent review approval or refusal
       |-- trusted host verifier receipt (narrow projection only)
       |-- fresh comparison revalidation (exact same generation)
       v
architecture.promotion-handoff/0.1
       |-- DESIGN_ONLY_UNRESOLVED: questions/conflicts/unqualified carrier
       |-- READY_FOR_SSC_REVIEW: approved, verified, no planner blockers
       v
SSC resolution REQUEST only (no lock)
       v
SSC validates identity, source lineage, source level,
   ::requires package paths, revisions and graph ambiguity
       v
Deployment separately qualifies target and artifacts
       v
Externally governed build / stage / deployment
```

`ConnectSelector~explain()` is a **read-only registered-route eligibility**
observation, not a proof of production transmission. Route authorisation and
availability can change, so the target service must revalidate them before use.
`CALLBACK` and `RTO2 CONTINUITY` in ConnectSelector dev5 are distinct semantics;
the planner does not silently substitute JSON-RPC or QueueFabric.

## ooRexx API

```rexx
::requires 'ArchitecturePromotion.cls'
review = .ArchitecturePromotionReview~new(comparison, 'minimal', -
  'architect-id', 'selected for local pilot', 'review://design')
review~disposition('grid', 'DEFERRED', 'architecture board', -
  'no distributed requirement', 'review://alternative-grid')
review~approve('independent-reviewer-id','review://approval')
/* Design-only until an authenticated host-supplied verifier is available. */
draft = review~handoff
/* A trusted verifier, injected by the host, implements:
   verifyArchitectureApproval(projectId,scenarioId,principal,evidence,snapshotJSON)
   -> Directory {verified:true, principal:<reviewer>,
                 scope:'ARCHITECTURE_PROMOTION',
                 generationVerified:true, proofRef:<trusted id>}
   The verifier must independently establish reviewer authorisation, current
   policy authority, and the currently active project generation.
   The module does not implement/endorse a verifier using caller assertions. */
proposed = review~handoff(comparison, trustedVerifier)
/* proposed.sscSubmission may still be .nil; never executes SSC. */
```

Trust is established by the embedding host and existing identity/policy
systems, **not** by accepting a caller-created `proofRef`. The test verifier
is explicitly synthetic and is not a production implementation.

## Frozen comparison and revalidation

- The review stores a JSON snapshot and returns fresh copies. Mutating an output
  cannot mutate the retained review. This is a logical snapshot, **not** a
  cryptographic content digest, signature, database transaction or durable journal.
- Submission for SSC review additionally requires `handoff(currentComparison, trustedVerifier)`
  with unchanged JSON evidence **and a current trusted authority check**.
  Changed policy, components, deployments,
  alternatives or cost assumptions require a new review.
- `readyForSSC` means eligible to **request** SSC resolution, never that SSC
  resolved a lock. SSC must independently validate the requested identities,
  source lineages/levels, exact file closure, cycles and ambiguity.
- SSC lock acquisition, checksum/signature authority and target deployment
  mutation remain separate services. No bundle is executable.
- Deployment must revalidate previously captured facts immediately before any
  target mutation. New legal obligations or revoked authority invalidate any
  earlier review. A future persisted review store must provide event journaling,
  generation fencing and revocation controls through approved platform services.

## Output and deliberate limits

`ArchitecturePromotionWriter~write(handoff, existingDirectory)` writes:

- `promotion-handoff.json`
- `review-decision.json`
- `selected-plan.json`
- `selected-build-request.json`
- `considered-alternatives.json` (full nonselected candidate plans)
- `ssc-resolution-request.json` (only if fresh and trusted gates pass)

All paths are checked for existing files first. Multi-file creation is **not
atomic**; durable/transactional publication belongs to Deployment or the
platform file/journal substrate. The review is not a live policy decision,
a legal compliance certificate, an IAM credential or a cost quote.
