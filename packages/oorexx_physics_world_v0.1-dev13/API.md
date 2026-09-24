# Physics World API — v0.1-dev10

## Authorities

Physics consumes ooRexx Maths v0.8 and ooRexx Units v0.1-dev4 directly. No Physics-local unit compatibility API is exported.

## Existing dev4/dev5 surfaces retained

The existing `PhysicsWorld.cls`, `Mechanics.cls`, `Deformable.cls`, `Coupling.cls`, `Acoustics.cls`, `MechanicalAcoustics.cls`, `Fluids.cls`, `ContactDynamics.cls` and `VesselDynamics.cls` public surfaces are retained. Dev7 adds `FreeSurfaceFluids.cls`; dev8 adds `Electromechanics.cls`; dev9 adds `DrivenAcoustics.cls` and `Thermal.cls` without replacing those surfaces.

### Rexx-tronics optical compatibility surface

The following dev4 public objects remain available unchanged for the documented Rexx-tronics dev8 optical adapter:

- `PhysicalWorld`;
- `PhysicalPose`;
- `OpticalBeamProbe`;
- `OpticalBeamReading`;
- `Photometry`;
- `OpticalSensor`.


## DrivenAcoustics.cls

### RadiatingPatchObservation

Retained observation of a radiating patch at one simulation time. Exposes typed time, normal velocity, normal acceleration, area, volume velocity and volume acceleration plus world position/normal.

### RigidRadiatingPatch

`RigidRadiatingPatch(name,rigidBodyState,localPoint,localNormal,areaQuantity)`

Binds a finite local patch to an existing rigid-body state. `observe(timeQuantity)` samples the body's actual point velocity and derives normal acceleration from strictly increasing observations. `observationAt(time)` interpolates the retained mechanical history for retarded-time acoustic evaluation.

### ContinuousMechanicalAcousticRenderer

- `pressureAt(radiator,acousticSolver,microphone,receiveTime[,attenuationFrequency])`
- `pressureQuantityAt(...)`
- `render(radiator,acousticSolver,microphone,duration,sampleRate[,startTime[,attenuationFrequency]])`

Uses compact-volume radiation `Q=A v_n`, retarded source time, actual acoustic medium density/sound speed, direct-path transmission and optional explicit attenuation reference frequency. `render` returns `AcousticSampleBuffer`. This is not a full finite-piston/directivity solver.

## Thermal.cls

### ThermalMaterialProperties

`ThermalMaterialProperties(name,specificHeatCapacity,thermalConductivity[,emissivity])`

Units-authoritative material properties. Development factories `approximateCopper` and `approximateGlass` are explicitly approximate, not metrology data.

### ThermalPowerObservation

`ThermalPowerObservation(timeQuantity,powerQuantity[,cause[,source[,evidence]]])`

An explicit signed heat-power handoff. Physics does not infer this from unassigned electrical power.

### ThermalNode

`ThermalNode(name,absoluteTemperature,heatCapacity[,body])` or `ThermalNode~fromMass(name,body,mass,material,temperature)`

Holds lumped absolute temperature, heat capacity and accumulated power. Typed observations expose temperature and heat capacity.

### ThermalConductionPath

`ThermalConductionPath(name,nodeA,nodeB,conductance)` or `~fromGeometry(name,nodeA,nodeB,material,area,length)`

Applies `q = G (T_b-T_a)` with `G=kA/L` for the geometric constructor.

### ThermalConvectionBoundary

`ThermalConvectionBoundary(name,node,ambientTemperature,heatTransferCoefficient,area)`

Applies `q = h A (T_ambient-T_node)`. The heat-transfer coefficient is explicit model input.

### ThermalRadiationBoundary

`ThermalRadiationBoundary(name,node,environmentTemperature,emissivity,area)`

Applies grey-body exchange `q = epsilon sigma A (T_env^4-T^4)` using the Stefan-Boltzmann constant.

### ThermalSolver

Owns nodes and heat-transfer links/boundaries. `step(dtQuantity)` applies current heat-flow rates then advances lumped temperature with `dT=P dt/C`. This explicit lumped solver is not a continuum PDE solver.


## Electromechanics.cls

### ElectricalDriveObservation

Typed electrical-peer observation:

`ElectricalDriveObservation(timeQuantity,currentQuantity[,voltageQuantity[,cause[,source[,evidence]]]])`

`timeQuantity` and `currentQuantity` must be `UnitQuantity`; optional voltage must be voltage-dimensional. Observations expose typed time/current/voltage and terminal electrical power. Anonymous scalar current is rejected.

### LinearElectromechanicalTransducer

`LinearElectromechanicalTransducer(name,movingState,movingLocalPoint,statorFrame,axisLocal,forceConstant[,reactionState[,reactionLocalPoint]])`

`forceConstant` is Units-dimensional `N/A`. `statorFrame` may be a `PhysicalPose` or `PhysicalMount`.

Methods include:

- `axis`, `movingPoint`, `relativeVelocity` / quantity;
- `forceForCurrent(currentQuantity)`;
- `backEmf` / quantity;
- `applyDrive(ElectricalDriveObservation)`.

`applyDrive` submits force to the ordinary rigid-body accumulator and optional equal/opposite reaction force to the stator body. It returns `LinearElectromechanicalActuationEvent`.

### RotaryElectromechanicalTransducer

`RotaryElectromechanicalTransducer(name,rotorState,statorFrame,axisLocal,torqueConstant[,reactionState])`

`torqueConstant` is Units-dimensional `N*m/A`. It exposes reciprocal torque/back-EMF behavior and returns `RotaryElectromechanicalActuationEvent`.

### Actuation events

Both event types retain the originating drive observation and expose typed force/torque, relative speed, back EMF, mechanical conversion power, electrical conversion power, terminal electrical power (when supplied), unassigned terminal power and a power-closure error. For an ideal reciprocal transducer the closure error is zero within numerical precision.

These classes intentionally do not own winding resistance, inductance, controller switching or circuit solution.

## ContactDynamics.cls

### RigidContactHull

Explicit local-space support points used by finite rigid-plane contact.

Constructors:

- `RigidContactHull~box(width,height,depth[,context])`;
- `RigidContactHull~cylinder(radius,height[,segments[,context]])` — cylinder principal axis is local Y.

Observations: `name`, `localPoints`, `pointCount`.

### HullRigidBodyState

Subclass of `RigidBodyState` adding `contactHull`. All mass, force, impulse, velocity and pose authority remains in ordinary mechanics.

### CollisionSurface

Subclass of `CollisionPlane` adding:

- optional fixed `rigidBodyState` target, allowing contact impulse to be observed on a physical sheet/body;
- explicit non-negative `frictionCoefficient`.

### GeneralContactMechanicsSolver

Subclass of `MechanicsSolver`. It preserves inherited sphere collision and adds finite hull/plane contact using translational + rotational effective mass and constant-Coulomb tangential impulse.

Finite contact emits ordinary `MechanicsContactEvent` objects with kind `HULL_PLANE`.

### RigidTumbleTracker

Observations:

- `cumulativeAngleRadians` / `cumulativeAngleQuantity`;
- `turns`;
- `fullTurns`;
- `peakAngularSpeed` / `peakAngularSpeedQuantity`;
- `sampleCount`;
- `contactCount`.

`turns` is integrated angular travel, not a guessed tumble score.

## Mechanics additions

`MechanicsMassProperties` adds:

- `solidCylinder(mass,radius,height)`;
- `hollowCylinder(mass,innerRadius,outerRadius,height)`.

The principal cylinder axis is local Y.

`MechanicsSolver` accepts an optional fourth constructor argument `startTime`, preserving simulation time when an analytical pre-contact phase is used.

It also exposes `planes` and `recordContactEvent(event)` as the extension SPI used by the finite-contact solver.

## VesselDynamics.cls

### FreeFallDrop

`FreeFallDrop(dropHeight[,gravityMagnitude])`

Observations:

- `height` / `heightQuantity`;
- `gravityMagnitude` / `gravityQuantity`;
- `impactSpeed` / `impactSpeedQuantity`;
- `fallTime` / `fallTimeQuantity`.

This is ideal uniform-gravity vacuum free fall only.

### ContainedFluidLoad

Represents retained liquid whose gross rigid motion follows the vessel.

Constructors:

- `filledCylinder(fluidMedium,radius,height)`;
- `filledCylinderByVolume(fluidMedium,radius,volume)`.

Observations include `medium`, `volume`, `volumeQuantity`, `massProperties`, `mass`, `massQuantity`, `radius`, `height`.

`combineCenteredAligned(dryMassProperties)` combines dry and wet principal mass/inertia only when centres and principal axes coincide.

### VesselImpactExperiment

`VesselImpactExperiment(mechanicsSolver,vesselRigidBodyState,structuralAcousticCoupler,acousticSolver,microphone)`

`run(duration,dt,sampleRate[,startTime])` advances the configured post-drop/contact system and returns `VesselImpactReport`.

### VesselImpactReport

Observations:

- `totalMass` / `totalMassQuantity`;
- `turns`, `fullTurns`, `contacts`;
- `peakAngularSpeed` / quantity;
- `peakPressure` / quantity;
- `rmsPressure` / quantity;
- `splDb`;
- `duration` / quantity;
- `sampleBuffer`.

The SPL is derived from the rendered microphone pressure buffer relative to 20 uPa unless a different acoustic buffer reference is explicitly used.

## Fluids.cls

Retains dev5 `FluidMedium`, spatial fluid regions, `FluidField`, hydrostatic/uniform/rigid-rotation fields, `LaminarCircularPipeFlow`, `FluidPathlineIntegrator`, `FluidProbe`, `FluidHydrodynamicProfile` and `FullySubmergedFluidCoupling`.

New-fluid arithmetic qualifications use explicit higher working precision internally where scalar ooRexx operations would otherwise fall back to default method precision.

## AcousticSampleBuffer additions retained

`rmsSplDb([referencePressure])` and `peakSplDb([referencePressure])` expose pressure-level observations from physical Pa samples.

# Dev7 free-surface additions

## FreeSurfaceFluids.cls

### RectangularTankGeometry

`RectangularTankGeometry(length,width,height[,cellCount])`

A vessel-local rectangular prismatic cavity. `cellCount` defaults to 64 and must be at least 8.

Observations: `length`, `width`, `height`, `cellCount`, `cellWidth`, `capacity`, `capacityQuantity`, `cellCentre(index)`.

### RectangularTankSlosh1D

`RectangularTankSlosh1D(fluidMedium,tankGeometry,fillVolume[,dampingRate[,cfl[,minimumDepth]]])`

Explicit one-dimensional nonlinear shallow-water free-surface solver.

Key operations/observations:

- `resetFlat`;
- `seedFundamental(amplitude)`;
- `step(dt[,tangentialEffectiveGravity[,normalEffectiveGravity]])`;
- `maxStableTimeStep([normalGravity])`;
- `depths`, `discharges`, `depthAtCell(index)`, `velocityAtCell(index)`;
- `currentVolume`, `currentMass`;
- `centreOfMassLocal([context])`;
- `freeSurfacePointsLocal([context])`;
- `relativeMomentum`;
- `kineticEnergy`, `potentialEnergy`, `totalMechanicalEnergy` and UnitQuantity forms;
- `minSurfaceDepth`, `maxSurfaceDepth`, `surfaceRange`, `surfaceAmplitude`;
- `fundamentalAngularFrequency`, `fundamentalPeriod`, `fundamentalPeriodQuantity`;
- `snapshot`;
- `reactionReport([normalEffectiveGravity[,context]])`.

The fundamental period is the natural period of this shallow-water model, not a finite-depth dispersive wave claim.

### FreeSurfaceSnapshot

Retained observation of time, volume, mass, min/max depth, local liquid centre of mass, relative momentum, kinetic/potential energy and effective-gravity components.

### FreeSurfaceVesselLoadReport

Retains local force/torque, end-wall depths and pressure forces, liquid centre of mass, mass and normal effective gravity.

### FreeSurfaceVesselCoupling

`FreeSurfaceVesselCoupling(sloshModel,rigidBodyState[,localLongitudinalAxis[,localUpAxis]])`

Operations:

- `advanceKinematics(dt,bodyAccelerationWorld,gravityWorld)` — advance free-surface state from explicit body kinematics;
- `applyCurrentLoad([normalEffectiveGravity])` — submit current resolved fluid load to the bound rigid body;
- `beforeMechanicsStep(mechanicsSolver,dt)` / `afterMechanicsStep(mechanicsSolver,dt)` — explicit staggered mechanics coupling;
- `lastBodyAcceleration`, `lastEffectiveGravityLocal`, `lastLoadReport`;
- `centreOfMassWorld`, `freeSurfacePointsWorld` — project local liquid state through the authoritative vessel pose.

Loss of positive floor-normal effective gravity fails closed because ballistic/inverted free-surface flow is outside this model.


# Dev10 two-axis free-surface additions

## FreeSurfaceFluids2D.cls

### RectangularTankGeometry2D

`RectangularTankGeometry2D(length,width,height[,xCells[,zCells]])` defines a vessel-local rectangular prismatic tank with a two-dimensional horizontal grid. Local X is longitudinal, local Z is lateral and local Y is up.

### RectangularTankSlosh2D

`RectangularTankSlosh2D(fluidMedium,tankGeometry,fillVolume[,dampingRate[,cfl[,minimumDepth]]])` evolves `h`, `qx` and `qz` with the conservative 2-D nonlinear shallow-water equations.

Key operations/observations include:

- `resetFlat`;
- `seedStandingMode(amplitudeX[,amplitudeZ])`;
- `step(dt[,effectiveGravityX[,effectiveGravityZ[,normalEffectiveGravity]]])`;
- `maxStableTimeStep([normalGravity])`;
- `depthAtCell(i,j)`, `dischargeXAtCell(i,j)`, `dischargeZAtCell(i,j)`;
- `velocityXAtCell(i,j)`, `velocityZAtCell(i,j)`;
- `currentVolume`, `currentMass`;
- `centreOfMassLocal`, `relativeMomentum`;
- `kineticEnergy`, `potentialEnergy`, `totalMechanicalEnergy`;
- `minSurfaceDepth`, `maxSurfaceDepth`, `surfaceRange`, `surfaceAmplitude`;
- `fundamentalPeriodX`, `fundamentalPeriodZ` and typed UnitQuantity forms;
- `freeSurfacePointsLocal`, `snapshot`, `reactionReport`.

### FreeSurfaceSnapshot2D

Retains time, volume, mass, min/max depth, liquid centre of mass, two-axis relative momentum, energy and all three effective-gravity components.

### FreeSurfaceVesselLoadReport2D

Retains the local net force/torque plus integrated pressure resultants on the left, right, near and far tank walls. Floor-normal load acts through the instantaneous resolved liquid centre of mass.

### FreeSurfaceVesselCoupling2D

Binds the 2-D free surface to an existing `RigidBodyState`. `advanceKinematics` accepts a world-space body acceleration and gravity vector; `applyCurrentLoad` submits the resolved load to rigid mechanics. `beforeMechanicsStep` / `afterMechanicsStep` provide the same explicit staggered coupling pattern as the 1-D model.


## Fluid containment / breach API (dev11)

- `FluidContainmentBoundary2D(tankGeometry)` — containment authority; `CLOSED`, `BREACHED`, or explicit `FRAGMENTED` fail-closed state.
- `RectangularBoundaryBreach2D(id, side, coordinate, sillElevation, openingHeight, openingWidth, dischargeCoefficient [, source])` — explicit qualified wall opening.
- `BreachedFreeSurfaceVessel2D(sloshModel, containmentBoundary)` — conservative retained/escaped-fluid coordinator.
- `EscapedFluidParcel` — retained escaped mass/volume, local release position/velocity, time and breach provenance.
- `FractureContainmentBinding2D` — consumes retained `FractureEvent`s and opens only explicitly bound breaches.
- `RectangularTankSlosh2D~drainVolumeFromCell(i,j,volume)` — conservative drainage primitive used by containment coupling.

The breach law is `Q = Cd A_sub sqrt(2 g h_head)`. `Cd` is explicit input. Fragmented/moving containment geometry remains outside this solver and fails closed.


## External escaped-fluid parcel API (dev12)

- `ExternalFluidParcelState(escapedParcel)` — live external position/velocity/time retaining the original escaped-fluid evidence.
- `ExternalFluidPlane(point, normal [, restitution [, name]])` — explicit infinite plane for the first external contact model.
- `ExternalFluidContactEvent` — contact time, parcel, plane, hit point, impulse, pre/post velocity.
- `ExternalFluidParcelWorld([gravity [, startTime]])` — admits parcels, advances ballistic motion, resolves plane contacts and exposes total mass/volume/momentum.
- `EscapedFluidWorldBinding(breachedVessel, externalWorld)` — exactly-once transfer from breach evidence into the external parcel world and retained+external mass accounting.

The external parcel lane is intentionally not a CFD solver.


## Rotating machinery API (dev13)

- `RotorMassEccentricity(eccentricMass, localOffset)` — explicit imbalance and centrifugal force from actual angular state.
- `CompliantRadialBearing(bodyState, worldAnchor, worldAxis, radialStiffness [, radialDamping [, rotationalDrag [, name]]])` — radial support compliance/damping and optional axial rotational drag.
- `RotationalViscousFriction(bodyState, worldAxis, coefficient)` — opposing torque plus dissipated-power evidence.
- `RotatingAssembly(bodyState)` — composition of eccentricities, bearings and rotational friction.
- `HarmonicSampleHistory` / `HarmonicObservation` — frequency-component observations from sampled resolved histories.

No arbitrary chatter, imbalance, vibration or harmonic multiplier is introduced.
