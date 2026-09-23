# ooRexx Physics World v0.1-dev3

A renderer/toolkit-independent physical-world library for ooRexx.

Dev3 keeps the geometric-optics and classical-mechanics work, adds acoustics as a peer solver over the **same world/body/pose authority**, adds live physical mounting for cross-domain experiments, and moves dimensional quantity authority to the independent `ooRexx Units v0.1-dev1` library.

## Shared authorities

- **ooRexx Maths v0.8** owns vectors, matrices, transforms, quaternions, rays and numeric context.
- **ooRexx Units v0.1-dev1** owns dimensions, unit conversion, source/display-unit identity and quantity arithmetic.
- **Physics World** owns spatial bodies, poses, medium occupancy and solver-specific physical interactions.

`PhysicsDimension`, `PhysicsUnit`, `PhysicsQuantity` and `SI` remain as compatibility names, but they are now facades over the independent Units objects rather than a second dimensional system.

## Acoustics in dev3

Sound is not implemented as optical rays with a different velocity. Dev3 establishes coherent monochromatic pressure propagation with:

- `AcousticMedium` density, sound speed, impedance, wavelength and attenuation;
- `AcousticPhasor` coherent amplitude/phase addition;
- ideal isotropic `AcousticToneSource` objects;
- `AcousticMicrophone` / `AcousticReading` with pressure, SPL and path evidence;
- propagation delay;
- normal-incidence impedance reflection/transmission;
- finite rectangular specular surfaces using real geometry;
- direct + first-order reflected paths;
- shared optical/acoustic spatial medium regions;
- body- and `PhysicalMount`-attached sources/sensors that follow mechanics automatically.

A water-filled world is therefore just a world whose acoustic medium is water. There is no `underwaterSoundMode`.

General mixed-medium acoustic propagation currently **fails closed**. The interface equations exist, but dev3 does not pretend that arbitrary air/water/glass paths, diffraction or room reverberation can be replaced by a scalar correction.

## Cross-domain coupling

`PhysicalMount(parent, localPose)` is a live transform relationship. A lamp, microphone, light sensor or speaker can be mounted on a mechanically moving body without a coordinate-copy loop.

The included crash optical-switch qualification proves the intended pattern:

```text
car -> collision -> spring/brick motion
                         |
                         v
                 authoritative body pose
                         |
                         v
                  optical ray geometry
                         |
                         v
                  sensor dark / clear
```

No collision callback toggles the optical sensor.

Acoustics follows the same rule: a speaker bound to a moving body or mount changes position because mechanics changed the shared pose; the acoustic solver simply observes the new geometry.

## Mechanics retained

- mass and principal inertia;
- gravity / weight;
- arbitrary forces and torques;
- velocity, acceleration and momentum;
- impulses and off-centre angular impulse;
- quaternion orientation integration;
- Hooke springs with damping and moving local attachment points;
- semi-implicit Euler integration;
- sphere/plane and sphere/sphere restitution collision.

## Running tests

Put these on `REXX_PATH`:

1. this package `rexx/`;
2. `ooRexx Units v0.1-dev1/rexx`;
3. `ooRexx Maths v0.8/rexx`.

Then run with ooRexx 5.3.0 r13196:

```sh
./run_tests.sh
```

## Honest dev3 boundary

Optics remains geometric rather than wave/diffraction optics. Acoustics is coherent monochromatic direct + first-order finite planar specular propagation, not a mature room-acoustics engine. Mechanics remains foundational rigid-body work rather than FEA/multibody dynamics. Fluids, diffraction, broadband/time-domain acoustics, Doppler, friction, joints, deformable bodies, thermal physics and full electro-mechanical transducers remain future solver capabilities over the same world.
