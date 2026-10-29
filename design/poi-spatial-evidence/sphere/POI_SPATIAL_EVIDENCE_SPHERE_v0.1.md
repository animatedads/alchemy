# POI Spatial Evidence — LLM Gopher Sphere Candidate v0.1

**Sphere ID:** `sphere:poi-spatial-evidence` (proposed; not yet registered with LLM Gopher)  
**Owner:** POI workbench development lane  
**Date:** 2026-10-23  
**Status:** SOURCE_CANDIDATE / NOT_RUNTIME_QUALIFIED

## Boundary and intention

A POI-centred, case-scoped spatial and temporal investigation application using Wire3D's renderer-neutral scene contract. It must present evidence, not create truth from visualization. Finding media is delegated to a library/resolver. Source media may be hidden without deleting links or lineage.

## Semantic objects and relationships

| Object | Owns | Does not own |
|---|---|---|
| PoiCase | Case revision, access scope, subject/evidence references | Source-media authority |
| PoiSubject | Case-local subject reference, identity hypotheses | Biometric identification truth |
| PoiPlace | Place references and separately sourced geographic extent | Invented precision |
| PoiTemporalClaim | Original civil expression, resolution/uncertainty metadata | Timezone rules and UTC conversion (Single Time Service) |
| PoiMediaReference | Library locator, digest/version, frame/sample span | Media bytes or access policy |
| PoiObservation | Assertion, evidence refs, contradiction/review state | Unqualified certainty |
| PoiMethodRun | Human/automated lineage, exact input/output and calibration refs | Claim that tool scores are probabilities |
| PoiAssociation | Qualified candidate relationship with evidence | Proof of contact from co-presence |
| PoiSceneProjection | Stable renderer-neutral visualization references | Evidence mutation or case authority |

## Contract invariants

1. Assertions have stable IDs, provenance and correction/retraction lineage.
2. `DATE_ONLY` is never silently converted to midnight. Unknown timezone is unresolved; historical/future DST requires Single Time Service.
3. Spatial extent and precision are explicit. Country and station can be represented without forcing common accuracy.
4. Candidate overlap does not establish identity, interaction, travel or contact.
5. Every automatic output declares method execution and method-specific confidence calibration. Missing provenance is `UNKNOWN`, not `HUMAN`.
6. Source integrity, spatial precision, temporal precision, identity qualification, method calibration, contradiction and review status remain independent axes.
7. A graph edge must expose evidence refs, reason and class; retractions and rejected matches remain inspectable.
8. Case authorization and source-media dereference authorization are independently enforced. No UI visibility grants effectful authority.
9. Projections are deterministic from explicit inputs, preserve unknowns and do not fabricate people, positions, times, scores or relationships.
10. Presentation hiding, camera orbit, selection and timeline scrub cannot modify the evidential record.

## Existing code

- `design/poi-spatial-evidence/CONTRACT-dev1.md` — object and qualification contract.
- `design/poi-spatial-evidence/src/PoiEvidenceLedger.cls` — first ooRexx source candidate, unqualified. Contains `PoiEvidenceLedger`, `PoiEvidenceRecord`, `PoiMethodRun`. Its conservative `candidateWith` requires identical explicit resolved time expressions and place IDs and is **not** a genuine interval overlap implementation.
- No executable media resolver, temporal adapter, persisted journal or Wire3D presentation yet.

## Evidence and dependencies

- Wire3D latest package observed: `oorexx_wire3d_v0.1-dev29.25-collector-join.zip` (Library, 2026-10-19); not yet bound to POI.
- Single Time Service: Library `PA-STK-TIME` establishes civil/instant/timezone semantics. Callable methods have **not** been verified.
- Existing LLM Gopher project component catalog has `sphere:wire-ui`, but no registered `sphere:poi-spatial-evidence` at this check. This file is a source-controlled sphere proposal, **not** an assertion of Gopher registration or validation.
- No human/person data used in the demonstration. Glasgow Central Station 2028-12-01, Glasgow Airport 2028-12-02 and Râmnicu Vâlcea 2028-12-03 are fictional date-only scene anchors.

## Acceptance gates and next increment

- Compile and exercise all ooRexx source under real interpreter, including negative tests and `candidateWith` false-positive prevention.
- Verify actual Time Service API, then implement interval comparison with uncertainty semantics and no invented timezone conversion.
- Implement media-library resolver by verified provider contract and explicit permission recheck.
- Implement POI scene projection, provenance inspector, hide/show media library and evidence graph on top of Wire3D.
- Produce source/fixture hashes and deterministic qualification reports; never claim a method was used without a run record.
- Submit this sphere to LLM Gopher only after discovering the authoritative sphere registration/update route; GitHub text alone does not constitute registration.

## Change log

- **2026-10-23 v0.1:** First POI sphere documentation; describes source candidate and outstanding qualification rather than presenting design as completed.

## Dev2 presentation increment (2026-10-28)

- `src/PoiEvidencePresentation.cls` projects ledger records to renderer-neutral rows; keeps identity/spatial/temporal/method certainty as `NOT_ASSESSED` rather than inventing a score.
- `edgeCandidate` returns `TEMPORAL_SPATIAL_CANDIDATE` only when the ledger's deliberately restrictive candidate predicate succeeds; otherwise `NO_RELATIONSHIP`. Neither is a finding of contact.
- `mediaPanel` returns `HIDDEN_PRESENTATION_ONLY`, with no mutation of the ledger or evidence references.
- **Qualification gap:** this is source-only, not executed under ooRexx; the temporal comparison is not yet integrated with Single Time Service; no 3D Wire3D renderer has been bound.
- Mailbox `poi-spatial-evidence`: the Wire3D dev29.25 comparison request returned no executed evidence. Requested that any subsequent qualification supply commands, exact archive digest and findings; no compatibility pass claimed.

## 2026-10-29 — GitHub and Library reconciliation

- GitHub contains `src/PoiEvidenceLedger.cls`, `src/PoiEvidencePresentation.cls`, and new `tests/test_projection.rex` (commit `726f09624e4bfe6ce1177c3d752d58b73f115a5b`). Test source covers date-only uncertainty, strict candidate matching, projection certainty, and media-panel visibility. **Not yet runtime-executed.**
- Rasen Falcon mailbox lane `poi-spatial-evidence` is active. No new executed Wire3D dev29.25 verification was received in this check; prior reply remains an evidence gap.
- Library search found instrumentation freshness/event/correlation materials and dev29.23 digest metadata. The exact dev29.25 archive was **not independently materialized or hashed in this run**. No claim of a verified dev29.25 compatibility pass.
- Programme priorities (website, mail, MU/MI internode communication, LDAP and private-CA HTTPS) remain owned by their respective implementation lanes; this POI workstream does not deploy or modify those services. Autobuilder is not running; do not infer qualification from source commits.
