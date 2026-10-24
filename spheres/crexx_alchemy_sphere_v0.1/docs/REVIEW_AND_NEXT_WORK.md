# Code review and next implementation work

Review status: candidate / manual review and runtime qualification pending.

## Observed risks
- Session-affine host-services negotiation must be exercised on nested entry and teardown.
- Synthetic Projection currently stands in for real Alchemy Foreign Object identity; do not allow a second durable identity authority.
- Native payload copy/finalize requires accounting and failure-path tests.
- RXPA values are borrowed only within active invocation; never retain callback handles.
- Fail-closed behavior must cover absent V2 services, invalid receiver, stale projection and callback signal.
- Plugin identity, package discovery and compiler import path must match the pinned CREXX build.

## Implementation order
1. Resolve compile errors using upstream tests/rxpa/rxpa_objects.c and .crexx as syntax/API authorities.
2. Integrate dev3 source files into this sphere under native/, tests/, scripts/.
3. Run real qualification and preserve logs.
4. Correct lifetime accounting and cleanup.
5. Replace test Projection with Alchemy Foreign Object adapter, preserving its authority.
6. Add reproducible CI and versioned dependency declaration.

Do not claim tests or GitHub source admission that have not happened.
