# Changelog

## v0.1-dev3

- Added acoustics as a peer solver over the same `PhysicalWorld`, geometry and pose authority.
- Added acoustic media (density, sound speed, impedance, attenuation), coherent phasors, ideal tone sources, microphones, SPL readings and path evidence.
- Added normal-incidence air/water interface reflection/transmission, finite planar specular reflection, direct propagation delay and coherent interference qualification.
- Added shared optical/acoustic `PhysicalMediumRegion` support and mechanics-moved acoustic source qualification.
- General mixed-medium acoustic propagation fails closed in dev3 rather than inventing an alignment/transmission scalar.
- Added cross-domain physical mounting via `PhysicalMount`. Mounted geometry consumes its parent's live pose; consumers do not copy or periodically synchronize coordinates.
- Added `OpticalBeamProbe` / `OpticalBeamReading` as a normalized optical instrument for occlusion and line-of-sight qualification over the existing geometric-optics solver.
- Added the crash optical switch qualification: a moving car collides with a wall, a spring-mounted brick continues under inertia, the spring compresses, and the same moving brick becomes a black optical absorber that interrupts a light beam mounted to the car.
- The light transition is not scripted from the collision. Mechanics changes the authoritative brick pose; optics independently observes the changed geometry.
- Added a rebound check proving the beam becomes visible again when the spring moves the brick clear.
- Preserved all dev2.1 mechanics and dev1 optics behaviour and continued qualification against the authoritative user-supplied Maths v0.8 implementation.
- Replaced Physics' private dimensional implementation with compatibility facades over the independent ooRexx Units v0.1-dev1 authority; existing `PhysicsQuantity` / `SI` callers remain compatible.

## v0.1-dev2.1

- Requalified the mechanics extension against the authoritative user-supplied ooRexx Maths v0.8 archive rather than the temporary compatibility shim.
- Repaired `MathVector3` scalar division assumptions in mechanics. Maths v0.8 intentionally exposes vector scaling through `vector * scalar`, not `vector / scalar`; mechanics now uses reciprocal scalar multiplication for acceleration, impulses, normalization and contact normals.
- Full optics + mechanics regression suite passes on ooRexx 5.3.0 r13196 with the real Maths v0.8 implementation.


## v0.1-dev2

- Added classical rigid-body mechanics as a peer solver over the existing `PhysicalWorld` and body `PhysicalPose`.
- Added SI mass/mechanics units: kilogram, gram, velocity, acceleration, newton, newton-second, joule, radian and radian/second.
- Added non-normalising pose vector transforms so force/velocity/torque magnitudes survive coordinate transforms.
- Added principal-axis mass/inertia models for point masses, solid spheres and solid boxes.
- Added force, torque, impulse, linear momentum, kinetic energy, gravity and symplectic-Euler integration.
- Added quaternion orientation integration from angular velocity.
- Added finite-anchor Hooke springs with viscous damping and off-centre force/torque application.
- Added infinite-plane/sphere and sphere/sphere impulse collision qualification with restitution and positional correction.
- Added movement-heading helper and mechanics regression/units suites.
- Preserved all dev1 geometric-optics, media, geometry and photometry behaviour.

## v0.1-dev1

Initial physical-world/material/geometric-optics spine.
