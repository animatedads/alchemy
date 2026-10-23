# POI Spatial Evidence Workbench — dev1 contract (2026-10-23)

Status: **implementation candidate**, not runtime-qualified. Repository: Alchemy. This is a POI-centred application over Wire3D, not a media-search application.

## Authority and objects

- `PoiCase`: stable case ID, access policy, subject references, revision and append-only event references.
- `PoiSubject`: case-scoped subject identifier. An identity hypothesis is not a verified real-world identity.
- `PoiPlace`: stable place reference, geometry/extent, coordinate reference system, precision and source authority. Country-scale and station-scale extents coexist.
- `PoiTemporalClaim`: original civil-time expression, timezone identifier, timezone-rules provenance, resolution state, earliest/latest possible instants and uncertainty. **Single Time Service owns conversion**; this module must not guess DST or offset.
- `PoiMediaReference`: immutable external media ID, source/version/digest, optional frame/sample/time span, and library resolver. Hiding the library changes only presentation.
- `PoiObservation`: subject/place/time proposition, evidence links, contradictions, method runs and review state.
- `PoiMethodRun`: HUMAN or AUTOMATED; tool name/version, configuration digest, input/output hashes, execution timestamp, calibration context, limitations and reviewer. Absence of this record means automation is **not proven**, not that it was not used.
- `PoiAssociation`: independently supported co-presence candidate, same-scene observation, asserted association or reviewed conclusion; never infer meeting/contact from spatial-temporal overlap.
- `PoiSceneProjection`: renderer-neutral spatial/time graph. Wire3D is a view, never evidentiary authority.

## Demonstration

Three **fictional, unpopulated** place/date markers: Glasgow Central Station (2028-12-01), Glasgow Airport (2028-12-02), Râmnicu Vâlcea (2028-12-03). Date-only claims remain date-only. No named subjects, locations of actual people or fabricated media are implied.

User workflow: select POI -> choose time/geographic extent -> link existing library media -> annotate frame/region/audio interval -> hide media library -> inspect assertions, supporting/contradicting evidence and provenance -> compare candidate associations -> export reproducible investigation snapshot.

## Qualification, not a single confidence score

Expose separate axes: source integrity, spatial precision, temporal precision, identification status, method calibration, human review, contradictory evidence. Numerical method scores retain their exact meaning, units, calibration population and provenance; never reinterpret a model score as probability of truth.

Every graph edge has an evidence inspector and one of: DIRECT_OBSERVATION, TEMPORAL_SPATIAL_CANDIDATE, ANALYST_ASSERTION, REVIEWED_CONCLUSION, DISPUTED, RETRACTED. Rejected/retracted findings remain visible in lineage, not active as positive findings.

## Security and retention

Case-level access control; source media access is re-authorised on dereference. Evidence exports include digests and redaction provenance. Never put biometrics or unreviewed identity suggestions in telemetry. Explicit human approval for effectful operations. Support correction/retraction without erasing prior lineage.

## Integration qualification gates

1. Resolve actual Single Time Service callable API from current Library package before coding time conversions.
2. Resolve actual media-library locator and permissions API before binding.
3. Resolve Wire3D dev29.25 scene and live projection contracts; no competing renderer.
4. Implement append-only ooRexx evidence records, deterministic projection and tests for date-only time, uncertain overlap, contradiction, method provenance and library hide/show.
5. Prove that no candidate overlap is automatically upgraded to identity/contact.
6. Qualify with real ooRexx interpreter, Wire3D renderer and controlled media fixtures before claiming runnable.

This file is the initial source-controlled contract and qualification ledger; it is not a claim that the workbench is deployed.
