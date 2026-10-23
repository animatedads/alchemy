# Layered Audio intentions overlay v0.22-dev8

This package is the source-form continuation of the Layered Audio dynamic
intention work. It is deliberately an overlay around the authoritative Layered
Audio object model rather than a replacement Audio implementation.

## Authority boundary

- Layered Audio owns recording, element, view, boundary, lineage and acoustic
  evidence truth.
- Intention Service owns interpretation, clarification and READY-gated dispatch.
- Management Intention Discovery owns federation and bounded relationship
  traversal.
- Storage Fabric owns durable object identity, locations, materialisation and
  replica semantics.

Audio intention discovery is live and side-effect-free. Candidates retain the
actual ooRexx domain objects; IDs and paths are join/evidence values and are not
substitutes for selected Audio objects.

## dev8

dev8 closes the Management wiring gap left by dev7.

`AudioManagementInstaller~install(...)` composes the Audio provider with the
public Management Intention Discovery contracts:

- `ManagementSelfAssessingIntentionSurfaceSource`
- `ManagementRelationshipProviderSource`
- `ManagementRelatedSurfaceDiscovery`
- `ManagementIntentionExplorer`

The installer returns `AudioManagementRegistration`, retaining the exact
registered source objects, related-source provider and explorer.

This does not make Management authoritative for Audio and does not teach Audio
Storage semantics. An optional Storage intention source may be supplied as a
separate authority and becomes reachable only through Audio-published
relationships such as element -> Audio Storage binding -> durable Storage
identity.

## Current contracts

- `audio.intentions/0.8`
- `audio.intentions.management/0.2`
- Intention Service baseline: v0.1-dev11
- Management Intention Discovery baseline: exact Library v0.1-dev8 package

## Qualification

The dev8 source/package was checked with the strict ooRexx standards enforcer
with zero errors and zero warnings. Manifest verification, shell syntax and ZIP
integrity passed. A fresh ooRexx 5.3.0 r13196 runtime pass for dev8 is still
pending in the current execution environment; predecessor dev6 runtime evidence
must not be promoted to dev8 runtime evidence.

The regression `tests/test_audio_management_installation.rex` locks canonical
installer composition, native object identity preservation, Storage authority
separation and fresh discovery after a live Audio graph mutation.
