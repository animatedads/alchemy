# F11 rear exterior geometry — dev48

Authoritative geometry added from the 2026-09-29 property description.

- Lower paved parking/access level: z = 0.0 m.
- Property rear plane: y = 0.0 m in the accepted F11 plan convention.
- Stairwell ground aperture: 1.0 m wide x 2.0 m high, base z = 0.0 m.
- Property floor remains z = 3.0 m.
- Rear terrain step: y = -4.0 m, z = 0.0..1.5 m.
- Rear terrain step is modeled as a hard vertical reflector.
- Edge ramps are not acoustic surfaces because their propagation effect was stated
  to be negligible.
- Exact paved-ground reflection material remains unspecified and is not invented.

`F11RearExteriorGeometry~addToSolver()` adds the hard terrain step and extends the
stairwell shaft from lower ground to the property floor. The rear stairwell wall is
split into two jamb surfaces plus a lintel; the central 1 m x 2 m span is deliberately
absent and therefore remains a true acoustic opening.

The rear terrain reflector spans the accepted property width rather than an invented
independent width.
