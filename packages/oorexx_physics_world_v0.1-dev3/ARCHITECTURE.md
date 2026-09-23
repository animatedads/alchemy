# Architecture

## Authority split

`ooRexx Maths` owns numerical and 3-D mathematical semantics: vectors, matrices, angles, quaternions, transforms, rays and conventions.

`ooRexx Units` owns dimensional signatures, unit definitions, conversion semantics, source/display-unit identity and quantity arithmetic.

`Physics World` owns spatial occupancy, body identity/pose, material boundaries and physical interactions. Physics retains compatibility names for its old quantity classes, but they delegate to Units rather than defining a competing unit system.

Future domain solvers such as thermal, mechanical, acoustic and electromagnetic physics should reuse the same body identity and pose rather than inventing parallel worlds.

Instruments observe world truth. They do not own or fabricate it.

## Layering

```text
Maths v0.8
  vectors / transforms / rays / numeric context
                |
                v
Units quantity authority
                |
                v
Physical pose / geometry / material
                |
                v
PhysicalWorld spatial occupancy
                |
        +-------+-------+
        |               |
 optical solver      mechanics solver      future solvers
        |                  |
 emitter paths       forces / momentum / springs / contacts
        |                  |
 sensors          shared body pose is updated
```

## Spatial media

A global boolean such as `underwater=true` is explicitly rejected.

The world has an ambient medium and may contain dielectric volumes. `PhysicalWorld~mediumAt(point)` selects the authoritative medium at a point. Nested volumes use explicit `mediumPriority`; equal-priority conflicting media fail closed rather than choosing by insertion order.

That supports, for example:

```text
air room
  + water tank
      + glass prism
```

At a point inside the prism the glass medium wins. Immediately outside the prism but inside the tank, water wins. Outside the tank, air wins.

The same rule is used by ray transmission at a dielectric boundary. The solver probes the physical world immediately beyond the interface to discover the next medium instead of assuming that every object exits into a single ambient medium.

## Geometry is authoritative

A mirror is a finite shape with a pose and reflective material. A prism is a finite convex body with a pose and dielectric material. A sensor is a finite aperture.

Consequently there are no solver parameters named `alignment_factor`, `mirror_bonus`, `beam_hit_fraction`, `prism_mode` or `underwater_mode`.

If an object moves, rotates, grows, shrinks, occludes another object or changes material, the geometry/material state changes and the resulting physical paths change.

## Optical boundary

For a dielectric boundary dev1 computes:

- entry/exit orientation from the ray and outward surface normal;
- refractive index of the current and next media at the ray wavelength;
- Snell transmission;
- unpolarised Fresnel reflectance;
- a reflected branch;
- a transmitted branch when total internal reflection does not apply.

For a mirror it computes geometric reflection and applies reflectivity.

For an absorber it terminates the path.

A sensor terminates a path and records the arriving weight by wavelength.

## Quantities

Physical dimensions are represented by seven SI-base exponents. Unit objects carry a scale and dimension. Quantity arithmetic propagates dimensions.

This catches the class of error where area conversions are left as comments beside untyped floating-point numbers.

Example:

```text
66,200 lx * 1 cm^2
= 66,200 lm/m^2 * 0.0001 m^2
= 6.62 lm
```

The dev1 regression suite verifies this directly with `PhysicsQuantity` objects.

## Numerical scope

The exact rectangular solid-angle helper is intentionally separate from the general ray tracer. It is a useful closed-form reference for source/sensor qualification and prevents the general solver from being accepted merely because a coarse ray sample happens to look plausible.

Future source integration should be adaptive/deterministic and should retain spectral/radiometric units throughout propagation rather than hiding accuracy behind arbitrary alignment coefficients.


## Classical mechanics boundary (dev2)

Mechanics is a solver over the same bodies and poses used by optics. `RigidBodyState` owns dynamic state but not a duplicate geometric position. Integration writes the referenced body's `PhysicalPose`, preserving one spatial truth.

The foundational equations are explicit rather than tunable "movement factors":

- weight derives from `m g`;
- linear acceleration derives from `F / m`;
- impulse changes momentum;
- off-centre force and impulse use `r x F` / `r x J`;
- angular acceleration uses local principal inertia;
- spring force uses Hooke extension plus damping along the current geometric spring axis;
- orientation advances from angular velocity using a quaternion increment;
- collision response uses contact normals, restitution and inverse mass.

Dev2 uses a symplectic Euler step because it is simple, deterministic and materially better for mechanical energy behaviour than explicit Euler. It is not claimed to be a precision multibody integrator. Future solvers can add higher-order/adaptive integration behind the same state/world contracts.

Collision scope is intentionally honest: sphere-plane and sphere-sphere contacts are implemented. Arbitrary convex contact manifolds, friction, joints, deformable bodies, fluids and continuum mechanics are not simulated by invented coefficients.


## Cross-domain mounting and observation (dev3)

`PhysicalMount` is a live geometric relationship, not a copied coordinate. Its world transform is derived from `parent.pose * localPose` whenever a consumer asks for it. A lamp, sensor, microphone, camera, antenna or other instrument can therefore be mounted on a mechanically moving body without a synchronization loop.

`OpticalBeamProbe` is deliberately an optical instrument, not a mechanics callback. It emits a normalized ray from its mounted source pose toward its mounted finite sensor and asks the existing optical solver what reaches the detector. Any absorber, mirror or dielectric that mechanics has moved into the path is therefore visible automatically.

The crash-switch regression is the architecture proof:

```text
MechanicsSolver                         Geometric optics
      |                                       |
car hits collision plane                      |
      |                                       |
car velocity -> 0                             |
      |                                       |
brick momentum carries it forward             |
      |                                       |
spring compresses                             |
      |                                       |
brick OpticalBody.pose ---------------------->|
                                              |
                                    ray intersects brick
                                              |
                                     sensor receives zero
```

No event or boolean crosses from mechanics to optics. Shared world identity and pose are the coupling. That rule is intended to carry forward to acoustics, thermal physics and Rexx-tronics integration.


## Acoustics boundary (dev3)

Acoustics deliberately shares world identity, material occupancy and pose with optics/mechanics while keeping its own propagation semantics.

```text
PhysicalWorld
   |
   +-- geometry / pose / medium regions
   |
   +-- GeometricOptics
   |      refractive index / wavelength-dependent ray paths
   |
   +-- MechanicsSolver
   |      mass / force / momentum / collisions
   |
   `-- AcousticSolver
          pressure phase / impedance / sound speed / delay
```

A `PhysicalMediumRegion` can carry an optical medium, an acoustic medium, or both. `mediumAt(point)` and `acousticMediumAt(point)` therefore answer different physical questions about the same spatial volume. This is important for the "room under water" case: one world-state change affects both solvers through their own laws.

Dev3 acoustics uses coherent complex-like phasors represented by `AcousticPhasor`, so path contributions are added by amplitude and phase. Two equal in-phase sources double pressure amplitude; equal opposite-phase sources cancel. This is intentionally different from summing scalar sound-level values.

Finite specular reflections use real `RectangleShape` geometry and an image-source construction to locate the reflection point. If the finite wall does not contain that point, no reflected contribution exists. There is no reflection/alignment coefficient standing in for geometry.

The current solver is intentionally narrow: direct homogeneous-medium paths and first-order finite planar specular reflections are implemented. Diffraction, diffuse scattering, higher-order room reverberation, broadband/time-domain propagation, moving-medium effects, Doppler, transducer electro-mechanics and general multi-medium path segmentation remain future acoustic solver work.


## Units authority (dev3)

The dimensional layer is no longer privately implemented by Physics. `PhysicsQuantity` subclasses `UnitQuantity`, `PhysicsDimension` subclasses `UnitDimension`, and the `SI` compatibility catalogue delegates to `Units` wherever the shared catalogue already owns the unit. This preserves existing Physics callers while establishing one dimensional authority for Physics, Rexx-tronics and later physical libraries.

The compatibility surface is intentionally transitional. New code should prefer the independent Units names at public boundaries.
