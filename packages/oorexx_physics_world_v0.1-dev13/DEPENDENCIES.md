# Dependencies — v0.1-dev10

Required for qualification:

- ooRexx 5.3.0 r13196;
- ooRexx Maths v0.8;
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
