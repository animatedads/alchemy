# Changelog

## 0.1-dev5
- Substantial catalogue extension across mechanical, electromechanical, structural, thermal, sensor, battery and manufacturing-tool families.
- Fixed metricBolt: geometry assignment order, size-dependent shank area, optional head styles (HEX / SOCKET / COUNTERSUNK), capacity only when material supplies YIELD_STRESS.
- Added metricNut, nylocNut, plainWasher, springWasher, threadedRod, setScrew.
- Added shaftCollar, keyStock, rigid/flexible/jaw couplers, leadScrew, GT2 belt & pulley, spurGear, rack.
- Added extensionSpring and torsionSpring (geometry only; rate derivation remains Physics).
- Added parameterised structural stock: roundBar, squareBar, angleStock, SHS, RHS, tube.
- Added reusable package definitions: DIP, TO-220, 0603/0805/1206 chip.
- Added brushed DC motor, geared DC motor, NEMA 17 stepper, hobby servo, solenoid, PCB relay.
- Added thermalPad, thermalPaste.
- Added drillBit, endMill, latheInsert, sawBlade (geometry only; cutting physics stays in Physical Manufacturing).
- Added thermocouple, RTD/PT100, strainGauge, loadCell.
- Added AA/AAA/CR2032/18650/PP3 battery catalogue entries (physical/rating only; electrochemistry stays out).
- Expanded standardBenchSet to exercise the new families.
- All new material roles resolve through Materials; unknown materials fail closed.
- Requires Materials v0.1-dev3, Units v0.1-dev4, Rexx-tronics v0.1-dev15.

## 0.1-dev4
- Canonicalises catalogue material roles onto resolvable Materials IDs.
- Adds parameterised ISO coarse metric hex-bolt geometry from M2 through M12.
- Corrects bolt coarse pitch and makes head/shank geometry size-dependent.
- Adds parameterised round shafts, rectangular plate stock and compression springs.
- Adds reusable deep-groove bearing family: 608, 6000/1/2 and 6200/1/2/3/4.
- Generic bearing family deliberately omits manufacturer-specific load/speed claims.
- Adds strict material-reference and mechanical-family qualification tests.
- Requires Materials v0.1-dev3.

## 0.1-dev3
- Integrated upstream physical/manufacturing parts extension.
