# Dependencies — v0.1-dev10

Required for qualification:

- ooRexx 5.3.0 r13196;
- ooRexx Maths v0.16;
- ooRexx Units v0.1-dev4;
- RxMath from the selected ooRexx distribution.

Physics vendors neither Maths nor Units and exports no compatibility alias for either dependency.

## Maths authority

Physics uses authoritative Maths objects including `MathVector3`, `MathQuaternion`, `MathTransform3D`, `MathRay3D`, `MathContext` and `Maths~defaultContext`. Free-surface state is vessel-local; world projection uses the bound body's authoritative Maths pose.

## Units authority

Units v0.1-dev4 is the sole physical unit/dimension/quantity authority. The free-surface API accepts typed volume, length, time, acceleration and damping-rate quantities and returns typed mass, energy, force/torque and period observations where exposed. Electromechanics consumes typed current/voltage/time and uses derived `N/A` and `N*m/A` Units definitions; it returns typed force, torque, speed, back EMF and power evidence. Driven acoustics uses typed area, time, acceleration, pressure and sample-rate quantities. Thermal uses Units v0.1-dev4 absolute/delta temperature semantics plus derived J/K, J/(kg*K), W/K, W/(m*K) and W/(m^2*K) dimensions.

`run_tests.sh` fails closed unless the supplied Units package `VERSION` is `0.1-dev4`.

## Optional integration peers

- Rexx-tronics remains electrical/electronic authority and a consumer peer, not a Physics dependency. Dev9 preserves the `ElectricalDriveObservation` / back-EMF handoff and adds explicit `ThermalPowerObservation`; neither imports the peer circuit model.
- Audio/DSP remains a consumer of `AcousticSampleBuffer` physical pressure samples.
- A material/property authority may later supply state-dependent density/viscosity and vessel wall properties without changing solver ownership.
- More complete free-surface/CFD solvers may implement additional models beside `RectangularTankSlosh1D` and `RectangularTankSlosh2D`; they must not silently broaden its claims.

## dev27 qualification peer
Maths v0.9 supersedes v0.8 for dev27 qualification. Physics physical-model authority is unchanged; reusable interpolation/high-precision numerical foundations may be progressively delegated to Maths without moving physical semantics there.

## Optional dev31 live-state peer
`oorexx_journal_pointed_state_v0.1` is required only when `PhysicsJournalState.cls` / `PhysicsWorldJournal` is used. Coupled simulations should supply one shared `StateOfNationController` to all domain adapters.

## dev39 guitar physics
`GuitarStringMagnetics.cls` uses the ooRexx RxMath library for deterministic transcendental evaluation. It does not require Rexx-tronics. The optional peer seam qualification additionally requires Rexx-tronics dev22+ and its Units dependency.

## Maths v0.10 (dev44)
`GuitarMathsAcceleration.cls` requires Maths v0.10 `MathsBootstrap.cls`. The optional `NUMPY` provider additionally requires Maths' Foreign Runtime / `python_foreign.cls` dependency and NumPy. Physics does not vendor or emulate that provider.

## Maths v0.11 dynamics (dev45)
The accelerated reciprocal guitar path consumes ooRexx Maths v0.11 `MathDynamicsProvider.cls`. Its optional `SCIPY` BINARY64 provider uses Foreign Runtime v0.22.6 / ForeignPython with NumPy and SciPy. Physics calls only Maths APIs and does not call NumPy/SciPy directly.

## Maths v0.14 causal continuation (dev46.6)
`GuitarMathsDynamicsProjection` consumes `MathSecondOrderContinuation` and the checkpointable `MathSampleDelayLine` semantics introduced by Maths v0.14. Physics still owns the feedback path's physical minimum propagation delay and all pressure/pickup/amplifier/speaker/force-coupling semantics. The optional native SCIPY lane continues to require Foreign Runtime v0.22.6 with NumPy/SciPy.

## Maths v0.16 / portfolio review refresh (dev47)
Dev47 qualification is pinned to ooRexx Maths v0.16. The F11 deterministic warbler/moving-reflector experiment from dev38 is rebased onto Physics dev46.8. Portfolio review checkpoint 1 findings PHYS-001 and PHYS-002 are addressed by world-bound exact body inventories and transactional restore rollback.
