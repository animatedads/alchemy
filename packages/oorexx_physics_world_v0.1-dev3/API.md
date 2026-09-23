# Physics World API — v0.1-dev3

## Shared Units authority

Physics now consumes `ooRexx Units v0.1-dev1`. `PhysicsDimension`, `PhysicsUnit`, `PhysicsQuantity` and `SI` are compatibility facades over `UnitDimension`, `UnitDefinition`, `UnitQuantity` and `Units`. Existing Physics examples continue to work, while new consumers may use Units directly.

Physics-specific acoustic definitions currently exposed through `SI` include `microPascal`, `kilogramPerCubicMetre`, `pascalSecondPerMetre`, `wattPerSquareMetre` and `radianPerSecond`; these are ordinary `UnitDefinition` objects built on Units dimensions.

## Shared world

`PhysicalWorld` remains the authoritative spatial world. Mechanics does not create a second scene graph. A `RigidBodyState` references an existing world body and updates that body's `PhysicalPose`; optics therefore sees mechanically moved or rotated geometry immediately.

## Pose/vector distinction

`PhysicalPose` now exposes:

- `pointToWorld`, `pointToLocal`
- `vectorToWorld`, `vectorToLocal` — preserve magnitude
- `directionToWorld`, `directionToLocal` — normalize direction

Forces, velocity, momentum and torque must use vector transforms, not direction transforms.

## MechanicsMassProperties

Constructors:

- `pointMass(massKg, radiusOfGyration)`
- `solidSphere(massKg, radius)`
- `solidBox(massKg, width, height, depth)`

The object stores mass and local principal moments `Ix`, `Iy`, `Iz`.

## RigidBodyState

Wraps one existing physical body with dynamic state:

- mass/inertia
- linear velocity
- angular velocity
- accumulated force/torque
- fixed/dynamic flag
- restitution
- optional sphere collision radius

Operations include `applyForce`, `applyTorque`, `applyImpulse`, `momentum`, `kineticEnergy` and integration.

An off-centre force computes torque as `r × F`; an off-centre impulse computes angular impulse likewise.

## SpringConstraint

Connects two rigid bodies at local anchor points. Force is derived from geometry every step:

`F = k (length - restLength) + c(relativeSpeedAlongSpring)`

There is no `spring_alignment_factor`. Moving/rotating the bodies changes the anchor geometry and therefore the force.

## MechanicsSolver

Owns a set of dynamic states, springs and collision planes while referring to one `PhysicalWorld`.

`step(dt)` performs:

1. spring-force accumulation;
2. gravity and accumulated-force integration;
3. angular acceleration from principal inertia;
4. quaternion orientation integration;
5. positional/contact correction and impulse collision resolution.

The integration scheme in dev2 is semi-implicit (symplectic) Euler.

## Collisions

Dev2 deliberately starts with deterministic foundational contacts:

- sphere against infinite plane;
- sphere against sphere;
- coefficient of restitution;
- penetration correction;
- linear impulse and momentum conservation.

General convex collision detection, contact manifolds, static/dynamic friction, rolling resistance and constraint stacks are future mechanics work rather than hidden scalar approximations.


## PhysicalMount

`PhysicalMount(parent, localPose)` presents the same pose surface expected by physical geometry while deriving it from a live parent pose. The parent only needs to expose `pose`.

Important operations are `position`, `orientation`, `worldFromLocal`, `localFromWorld`, and the normal point/vector/direction transforms. Moving or rotating the parent therefore moves mounted geometry automatically.

## OpticalBeamProbe / OpticalBeamReading

`OpticalBeamProbe(world, sourcePose, sensorPose, width, height, wavelengthNm, weight, name)` installs a finite optical sensor and samples the existing `PhysicalWorld` ray tracer from source to sensor.

`sample` returns `OpticalBeamReading` containing the received normalized transmission, trace evidence, and source/target points. `blocked` is true only when the optical solver reports zero received weight.

The class is intended for light gates and line-of-sight qualification. It is not a substitute for future radiometric/photometric source integration.


## Acoustics

`AcousticMedium(name, densityKgM3, soundSpeedMps, attenuation)` exposes density, sound speed, acoustic impedance (`rho*c`), wavelength, wavenumber and attenuation. Development reference constructors are supplied for air and water.

`AcousticToneSource` represents an ideal isotropic monochromatic acoustic-power source. It may have its own pose, be attached to a physical body/local point with `onBody`, or consume a live `PhysicalMount` with `onMount`.

`AcousticMicrophone` may likewise use its own pose, `onBody`, or `onMount`, and records one `AcousticReading` per solved frequency. Readings retain the coherent pressure phasor, RMS pressure, SPL relative to the configured reference pressure, and the contributing propagation paths.

`AcousticInterface~normalIncidence(medium1, medium2)` returns pressure and intensity reflection/transmission coefficients from acoustic impedances.

`AcousticSurface(physicalBody, material)` associates acoustic reflection/transmission behaviour with ordinary finite world geometry. Dev3 reflection support is finite planar rectangular specular reflection.

`AcousticSolver` owns acoustic sources, microphones and acoustic surfaces over one existing `PhysicalWorld`. `solveTone(frequency)` adds coherent direct and first-order reflected contributions. Mixed-medium paths fail closed in dev3 rather than being reduced to an arbitrary transmission factor.

Additional SI units now include `hertz`, `pascal`, `microPascal`, `kilogramPerCubicMetre`, `pascalSecondPerMetre`, and `wattPerSquareMetre`.
