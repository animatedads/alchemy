# Changelog

## v0.1 - 2026-08-24

- Initial provider-neutral cross-provider AI route-selection package.
- Project deployment route declarations to ordinary WLU v0.12 stages without passing provider credentials, transport or Runtime Registry coordinates into WLU.
- Consume authenticated `WLURouteAdvisoryResult` evidence and the WLU v0.12 institutional route-decision gate rather than duplicating statistical or policy logic.
- Return detached `AIModelRoutePlan` values which explicitly confer neither WLU admission nor provider execution authority.
- Adopt Alchemy Objects v0.8 using preferred non-virtual `INIT` construction and complete STANDARD metadata.
