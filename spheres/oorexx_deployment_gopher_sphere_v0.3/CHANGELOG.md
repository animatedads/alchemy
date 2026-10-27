# Changelog

## 0.2 — 2026-09-10

- Advances executable authority to `oorexx_deployment_v0.1-dev3.zip` SHA-256 `796b4375b7abac6e13e5f23f632c8aa75f86fe777f3d7c130ea8e440ff5dbd79`.
- Adds SSC-backed ooRexx dependency authority and preserves the boundary between semantic `@source-requires ... AT_LEAST N` and package-load `::requires`.
- Adds explicit entry-package-scoped dependency closure so tests/examples do not become production dependencies by tree membership.
- Adds SSC_MANIFEST component/lineage/sourceLevel authority, durable dependency lock doctrine and REXX_PATH non-authority.
- Records fail-closed missing/ambiguous/unversioned cross-component dependency behavior.
- Records that AT_LEAST satisfies a known minimum but does not prove universal forward compatibility; accepted SSC impact qualification is a later integration step.
- Extends hosted MCP/Wire order to resolve/lock dependencies before package-load, composition, activation and live probe.
- Retains previous Audio fleet single-flight/readiness and transport-provider lessons.

## 0.1 — 2026-09-10

- Initial authoritative General ooRexx Deployment sphere grounded in dev2.

## v0.3 — 2026-10-27

- Added qualified/sealed SSC module deployment as preferred production dependency authority.
- Distinguished SEALED from DEVELOPMENT/LEGACY_INTAKE dependency modes.
- Added deterministic dependency namespace and generated REXX_PATH doctrine.
- Added component-root substitution protection and reachable-only materialisation.
- Recorded dev4 candidate SHA-256 `c6f04ddc6bcb80963161d3312b773cbc4c58fdbd2f99907662aa4a0d6ad23ce2` while retaining dev3 as last full r13196 baseline.
- Updated continuation/source-map/known-gap guidance to current Semantic Source Store APIs.
