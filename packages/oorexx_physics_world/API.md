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


## Rotating vibration API (dev14)

- `RotatingVibrationMode(name, worldAxis, modalMass, stiffness [, damping [, displacement [, velocity]]])`
- `RotatingVibrationSystem([startTime])`
- `ContactFrictionExcitation(surfaceNormal, staticCoefficient [, kineticCoefficient])`
- `RotorVibrationExperiment(mode [, startTime])`

Modal response owns mechanics only. Manufacturing geometry and part/material identities remain peer-library authority.


## General sampled/spectral observations (dev15)

- `SampledScalarHistory` — timestamped scalar samples; `mean`, `rms`, `component(frequencyHz)`, `spectrum(frequencies)`.
- `SpectralComponentObservation` — frequency, amplitude, cosine/sine components and sample count.
- `BroadbandSourceSample` — named position/pressure/time evidence carrier.
- `IncoherentSourceAggregator~combinedRms(contributions)` — root-sum-square aggregation only for explicitly incoherent RMS contributions.
- `HarmonicSampleHistory` remains a compatibility subclass for rotating-machinery clients.

No claim of FFT acceleration, psychoacoustics, architectural reverberation, diffraction, or crowd cognition is made.


## Rigid-body aerodynamics (dev16)

- `AerodynamicCoefficientModel`
- `AxialAerodynamicCoefficientModel(axialDrag,broadsideDrag[,spinLiftCoefficient[,spinDampingCoefficient]])`
- `AerodynamicBodyModel(rigidBody,axisLocal,length,maximumDiameter,airDensity,coefficientModel[,windVelocity])`
- `AerodynamicObservation`
- `SportsBallAerodynamicProjection~createRugbyLeague(projection,rigidBody,airDensity,coefficientModel[,windVelocity])`

The sports-ball adapter consumes physical projection data only. Coefficients are explicit Physics inputs and are never inferred from catalogue identity.


## Aerodynamic flight (dev17)

- `AerodynamicFlightSample` — time, position, velocity, orientation, angular velocity and aerodynamic observation.
- `AerodynamicFlightExperiment(rigidBody,aerodynamicBody[,gravity[,startTime]])` — `step`, `run`, `runUntilGround`, `history`.
- `RugbyBallFlightFactory~create(...)` — constructs Mechanics + aerodynamics from a Parts-style sports-ball projection and explicit coefficient model.

## Propulsion and wheel/tyre dynamics (dev18)
`PropulsionOperatingPoint`, `PropulsionMap`, `LinearStaticThrustMap`, `PropulsionUnit`, `PropulsionObservation`.
`RollingResistanceModel`, `ConstantRollingResistance`, `TyreWearLaw`, `EnergyProportionalWearLaw`, `WheelTyreState`, `WheelTyreObservation`.
Reference linear models are qualification models; production aircraft/engine/tyre data must be supplied by Parts/Materials or calibrated providers.

## Landing gear dynamics (dev19)
- `LandingStrutModel`
- `LinearLandingStrut(stiffness,damping,maxCompression)`
- `LandingGearState(supportedMass,strutModel,tyreState,verticalVelocity[,initialCompression[,startTime]])`
- `LandingGearObservation`
The reduced-order state couples resolved strut normal load to `WheelTyreState`; damping energy is derived from the explicit strut damping law.

## Aircraft ground dynamics (dev20)
`GroundGearStation(name,landingGearState,loadShare)`, `AircraftGroundExperiment(aircraftMass,groundSpeed,stations[,startTime])`, `GroundGearStationObservation`, and `AircraftGroundObservation`. Load shares are explicit projections rather than inferred aircraft geometry.

## Aircraft ground load transfer (dev21)
`LongitudinalGearGeometry(noseX,mainX,centreOfMassHeight)` requires main gear aft of COM and nose gear forward of COM.
`LongitudinalLoadTransferModel~resolve(mass,longitudinalAcceleration[,gravity])` returns `LongitudinalLoadObservation` with nose/main normal loads and shares. Positive acceleration is forward; braking acceleration is negative.

## Dynamic aircraft ground run (dev22)
`DynamicGroundTyreStation(name,axle,axleShare,tyreState)` identifies a NOSE or MAIN tyre station.
`DynamicAircraftGroundExperiment(aircraftMass,groundSpeed,stations,loadTransferModel[,startTime])` resolves axle loads every step from `LongitudinalLoadTransferModel`, distributes each axle load by explicit station share, advances each `WheelTyreState`, and records per-station physical evidence.

## Lateral axle load transfer (dev23)
`LateralAxleGeometry(trackWidth,centreOfMassHeight)`.
`LateralAxleLoadTransferModel~resolve(axleNormalLoad,lateralAcceleration[,gravity])` returns `LateralAxleLoadObservation(leftLoad,rightLoad,loadTransfer,...)`.
This is quasi-static roll/load-transfer evidence, not suspension roll dynamics.

## Tabulated aerodynamics (dev24)
`AerodynamicCoefficientTable1D(coordinates,values)` performs bounded linear interpolation.
`AerodynamicOperatingState(angleOfAttack,sideslipAngle,mach,relativeSpeed,airDensity)` carries explicit operating conditions.
`LongitudinalAerodynamicTableModel(CLtable,CDtable,CMtable,referenceArea,referenceChord)` returns coefficients, dynamic pressure, lift, drag and pitch moment.
Angles/coordinate convention belong to the supplied table contract; Physics does not infer coefficient data from aircraft identity.

## Aerodynamic coefficient surfaces (dev25)
`AerodynamicCoefficientSurface2D(firstCoordinates,secondCoordinates,valueRows)` performs bounded bilinear interpolation with no extrapolation.
`LongitudinalAerodynamicSurfaceModel(CLsurface,CDsurface,CMsurface,referenceArea,referenceChord)` evaluates the surfaces at `AerodynamicOperatingState~angleOfAttack` and `~mach`, returning q, lift, drag and pitch moment.

## Combined ground loads (dev25)
`AircraftCombinedGroundLoadModel(longitudinalModel,noseLateralModel,mainLateralModel)` composes the dev21 and dev23 equilibrium solvers and returns nose-left, nose-right, main-left and main-right normal loads.

## Aerodynamic ground loading (dev26)
`LongitudinalGroundAeroGeometry(noseX,mainX)` defines axle locations about the COM.
`LongitudinalGroundAerodynamicLoadModel~resolve(mass,longitudinalAcceleration,upwardAerodynamicForce,pitchMoment,centreOfMassHeight[,gravity])` resolves remaining nose/main contact loads.
Positive pitch moment is nose-up. This is a quasi-static equilibrium bridge, not pitch-dynamic contact.

## Static lateral payload loads (dev27)
`StaticLateralMassElement(name,mass,lateralOffset)` uses positive offset for port/left.
`StaticLateralOffsetLoadModel(trackWidth)~resolve(massElements[,gravity])` sums weight and roll moment, then resolves port/starboard reactions. This model is static payload-offset equilibrium and must not be substituted for dev23 acceleration-driven lateral transfer.

## Aircraft contained-fluid lateral composition (dev28)
`AircraftFluidLateralLoadModel(trackWidth)~resolve(staticObservation,fluidLoadReport)` combines dev27 static lateral equilibrium with `FreeSurfaceVesselLoadReport2D~localTorque~z`.
`resolveMoment(staticObservation,dynamicFluidRollMoment)` is the lower-level evidence seam used for qualification. It preserves the static total ground load and changes only its port/starboard distribution.

## 2-D free-surface CFL diagnostics (dev29)
`RectangularTankSlosh2D~cflDiagnostic([normalGravity])` returns `FreeSurfaceCflDiagnostic2D`.
Accessors: `cellIndex`, `depth`, `qx`, `qz`, `velocityX`, `velocityZ`, `waveSpeed`, `rateX`, `rateZ`, `totalRate`, `stableTimeStep`, `minimumDepth`, `depthRatio`.
The reported stable timestep is computed from the same CFL expression as `maxStableTimeStep`.

## PhysicalWorld freeze (dev30)
`PhysicalWorld~registerFreezeParticipant(participant)` registers explicit continuation state.
`PhysicalWorld~freeze` returns `PhysicalWorldCheckpoint`.
`PhysicalWorld~restore(checkpoint)` validates identity/schema inventory, restores body poses and participant state, then restores world simulation time.
Initial adapters: `RigidBodyFreezeParticipant(identity,rigidBodyState)` and `FreeSurfaceFreezeParticipant(identity,rectangularTankSlosh2D)`.
`RectangularTankSlosh2D~advanceCfl(...)` performs bounded CFL-respecting subcycling for a caller interval and returns `FreeSurfaceCflAdvanceObservation2D`.

## Acoustic impulse response (dev31)
- `AcousticBandTransfer(frequencyHz, pressureReflection, pressureTransmission, diffractionTransfer)`
- `AcousticSpectralMaterial(name)` / `addBand(response)` / `responseAt(frequencyHz)`
- `AcousticSpectralSurface(name, AcousticSurface, AcousticSpectralMaterial)`
- `AcousticDiffractionPoint(name, point, AcousticSpectralMaterial)`
- `AcousticEmissionBand` / `AcousticEmissionSpectrum`
- `AcousticImpulseResponseSolver~solve(sourcePosition, spectrum, receivers [, maxSeconds [, emissionTime]])`
- `AcousticImpulseResponseSolver~solveTrajectory(...)`
- `AcousticImpulseResponseSolver~firstArrivalUncertainty(...)`
- `AcousticForwardOracle~predict(candidatePoints, spectrum, receivers [, maxSeconds])`
- `AcousticReceiverImpulseResponse~firstArrival`, `arrivals`, `arrivalsWithin`, `energyProxy`
- `AcousticImpulseArrival~kind`, `distance`, `delay`, `arrivalTime`, `vertices`, `phasorAt`, `bandEnergyProxy`
- `AcousticCandidatePrediction~firstArrivalDifference(receiverB,receiverA)` and `energyRatio(numerator,denominator)`.

`receivers` is a Directory of receiver-name -> `MathVector3`. No receiver is privileged as FC/FD.

Diffraction transfer is explicit evidence in dev31. This prevents the solver from fabricating a universal corner-loss constant while still admitting physically traceable diffracted paths.

## Journal Pointed State adapter
`PhysicsWorldJournal(world [, sharedController [, componentPrefix]])` uses the peer Journal Pointed State v0.1 implementation. Supplying a shared controller is the required coupled-simulation pattern.

## Bounded second-order early arrivals (dev38)
`AcousticImpulseResponseSolver~solveEarly(source, spectrum, receivers [, maxSeconds [, maxInteractions [, emissionTime]]])`

`maxInteractions` is deliberately bounded to 1 or 2 in dev38. Order 2 adds:
- `DIFFRACTION_DIFFRACTION`
- `REFLECTION_DIFFRACTION`
- `DIFFRACTION_REFLECTION`

The original `solve()` remains the stable first-order API. Use `AcousticForwardOracle~predictEarly(...)` for a candidate lattice requiring these second-order arrivals.

Arrival evidence helpers:
- `interactionCount`
- `pathSignature`
- `AcousticReceiverImpulseResponse~arrivalsByKind(kind)`

Transmission vertices remain visible in path signatures but do not count as reflection/diffraction interactions.

## Electric-guitar string/magnetic seam (dev39)
- `GuitarStringPhysicalModel(openFrequencyHz [, scaleLengthM, linearDensityKgPerM, tensionN, inharmonicity, damping0, dampingN, modes])`
  - `frequencyForFret(fret [, bendSemitones])`
  - `effectiveLength(fret)`
  - `displacement(fret,time,positionFraction [, pluckFraction,pluckDisplacement,articulation,bendSemitones])`
  - `velocity(...)`
- `MagneticFluxGeometry(baselineFluxWb, fluxDisplacementGradientWbPerM [, pickupPositionFraction, evidence])`
- `GuitarStringMagneticFluxProbe(stringModel, fluxGeometry)~observe(...)`
- `PhysicsMagneticFluxObservation`: `timeSeconds`, `fluxWebers`, `stringDisplacement`, `stringVelocity`, `source`, `evidence`.

The flux observation is intentionally electrical-library-neutral. A Rexx-tronics consumer constructs its own `MagneticFluxObservation` from the time/flux/evidence fields and remains authoritative for Faraday conversion and circuit state.

## Guitar structural coupling (dev40)
- `GuitarBodyMode(name, frequencyHz, effectiveMassKg, dampingRatio, radiatingAreaM2 [, bridgeParticipation])`
- `GuitarBridgeCoupling(name, energyTransferFraction, bodyModes, sourcePosition)`
- `exciteFromString(stringModel, fret [, pluckDisplacementM, pluckFraction, articulation, bendSemitones, startTimeSeconds])`
- `GuitarBridgeExcitation`: `stringInitialEnergy`, `transferredEnergy`, `allocatedBodyEnergy`, `retainedStringEnergy`, `energyResidual`, `responses`.
- `GuitarBodyModeResponse`: damped `displacementAfter`, `velocityAfter`, `accelerationAfter`, `volumeVelocityAfter`, `volumeAccelerationAfter`, plus initial mechanical energy and evidence.

`GuitarStringPhysicalModel` additionally exposes `modeCount`, `linearDensity`, `tension`, `modalAmplitude`, and `modalEffectiveMass`.

## Reciprocal guitar string/body boundary (dev41)
- `GuitarCoupledOscillator(name,massKg,frequencyHz,dampingRatio [, initialDisplacementM, initialVelocityMps, kind, evidence])`
- `GuitarCoupledBoundary(stringModes,bodyModes,couplingStiffnessNPerM [, startTimeSeconds])`
  - `step(dtSeconds)` returns evidence with time, coupling force and energy before/after.
  - `totalMechanicalEnergy`, `stringModes`, `bodyModes`, `ledger`.
- `GuitarCoupledBoundaryFactory~fromStringAndBody(...)` derives retained string modal mass/frequency/damping/amplitude from `GuitarStringPhysicalModel` and combines them with supplied `GuitarBodyMode` objects.

## Guitar Maths acceleration (dev44)
`GuitarMathsModalRenderer(stringPhysicalModel, mathContext)`
- `displacementBank(...)` returns the Maths v0.10 oscillator bank representing the Physics string at a requested physical position.
- `renderDisplacement(..., sampleCount [, startSample, ...])` returns a `MathVector`.
- `renderPickupFlux(...)` returns `GuitarSampledFluxBlock`.

`GuitarSampledFluxBlock` retains start sample, sample rate, flux samples, the Maths displacement vector/context, geometry and Maths evidence. `startSample` is intentionally explicit so resumed/journaled simulations do not reset modal phase.

## Guitar Maths v0.11 dynamics (dev45)
`GuitarMathsDynamicsProjection(instrument, context)` exposes `system`, `dimension`, `initialDisplacement`, `initialVelocity`, `integrateFinal(dt,steps[,forces,method])`, and `advanceInstrument(dt,steps[,forces,method])`. The standard accelerated context is `.MathContext~binary64('SCIPY')`; `SYMPLECTIC_EULER` is the migration-compatible method for the existing guitar solver.

## Drum kit mechanics (dev46)

`DrumKitFactory~standardRockKit([origin])` creates a nine-voice physical kit. `DrumKitPhysics` exposes `strike`, `kick`, `snare`, `hiHat`, `setHiHatOpen`, `step`, `applyUniformAcousticPressure`, `pressureAt`, `attachToWorld`, `exportContinuationState`, and `restoreContinuationState`. The kit is an independent Physics participant and does not depend on or embed the guitar class.


## Guitar Maths v0.14 causal continuation (dev46.6)
`GuitarMathsDynamicsProjection~continuation([method])` creates a Maths-owned continuation at the projection's captured initial state and current instrument time.

`GuitarMathsDynamicsProjection~continuationFromCurrentState([method])` captures the authoritative current Physics DOF state into a new Maths continuation.

`GuitarMathsDynamicsProjection~advanceContinuationBlock(continuation, dt, steps[, forces])` advances one provider-selected block, writes the terminal displacement/velocity back into the same Physics oscillator/body objects, advances instrument time, and records Maths evidence. It does not decide causal block size; a feedback consumer must keep each block within its established minimum propagation delay.
