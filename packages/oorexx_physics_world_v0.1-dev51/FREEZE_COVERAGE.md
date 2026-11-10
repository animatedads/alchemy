# Physics World freeze coverage — v0.1-dev30

The freeze boundary is `PhysicalWorld`, not an individual solver.

## Covered in dev30
- `PhysicalWorld`: coherent checkpoint identity/schema, simulation time, body pose inventory, registered participant inventory.
- every body already registered with `PhysicalWorld`: authoritative `PhysicalPose`.
- `RigidBodyState`: linear/angular velocity plus force/torque accumulators through `RigidBodyFreezeParticipant`.
- `RectangularTankSlosh2D`: time, effective gravity and every h/qx/qz cell through `FreeSurfaceFreezeParticipant`.

Restore validates the complete participant identity/schema inventory before mutating the world.

## Immutable/stateless truth (reference/identity in a future durable manifest, no mutable payload required)
Examples include geometry definitions, material laws, coefficient tables/surfaces, unit definitions, mass-property definitions, pure photometry and other calculation-only objects.

## Stateful domains still requiring participant codecs before package-wide durable freeze can be claimed
- deformable-node/link accumulated state and fracture topology/events;
- thermal node temperatures, pending power and solver time;
- wheel/tyre angular speed, dissipated energy and wear;
- landing-gear compression/velocity/peak/damping history;
- external-fluid parcel positions/velocities/active state and system time/contact continuation;
- dynamic aircraft/ballistic/rotordynamic experiment integrator state where it is not reducible to registered body state;
- acoustic objects whose retained mutable buffers/readings are required for continuation (observation-only caches may instead be reconstructible).

dev30 is therefore the package-wide freeze *spine* plus the first two continuation codecs, not a claim that every mutable Physics class is already durable-checkpoint complete.
