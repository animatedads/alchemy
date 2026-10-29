# Dependencies — v0.1-dev7.5

## Current peer qualification target

- ooRexx 5.3.0 r13196;
- Physics World `0.1-dev50.2` from `packages/oorexx_physics_world`;
- ooRexx Maths `0.19` from `packages/oorexx_maths`;
- ooRexx Units `0.1-dev4` for typed physical/electrical quantities;
- RxMath from the selected ooRexx distribution.

## Electrical peer

Rexx-tronics remains the electrical authority. As of 2026-10-29, GitHub main does not publish an authoritative source tree containing the `RexxTronicsGuitar.cls` classes consumed by the full guitar electrical renderer. The dev29 material in Git is a handoff/candidate, not an accepted source publication.

Therefore dev7.5 splits qualification:
- Physics/Maths guitar, bass, drum, MIDI and concurrency seams may qualify independently.
- Full magnetic-pickup / loaded-network rendering requires `REXXTRONICS_ROOT/src/RexxTronicsGuitar.cls` and must fail closed when it is absent.
- No historical dev25/dev29 archive is silently vendored or promoted by this package.

Optional native Maths providers retain their own Foreign Runtime / NumPy / SciPy dependencies. The default current-peer smoke uses a PURE decimal Maths context and does not require them.
