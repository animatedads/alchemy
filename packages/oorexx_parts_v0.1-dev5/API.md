# API v0.1-dev2
`PartDefinition~new(id,family,description,parameters,materials,geometry,manufacturing,provenance,modelGrade)`

`PartDefinition~parameter(name)` — required named parameter, fail-closed.

`PartDefinition~material(role)` — material catalogue reference/name for a physical role.

`CommonParts~resistor(...)`, `~capacitor(...)`, `~diode1N4148`, `~diode1N4007`, `~ledRed5mm`, `~zener5V1`, `~standardBenchSet`.

The engineering extension adds `~metricBolt(size,length,materialId)`,
`~boltM6x30`, `~plateAl6061T6`, `~bearing608`
and `~heatsinkTO220`, each carrying dimensional, material and manufacturing
metadata suitable for deterministic downstream checks.

`RexxTronicsPartFactory~instantiate(definition,instanceId)` projects supported catalogue definitions into Rexx-tronics component objects. Behaviour remains owned by Rexx-tronics.

## Additional factories (v0.1-dev5)

metricBolt(size, length, materialId, headStyle), metricNut, nylocNut, plainWasher, springWasher, threadedRod, setScrew
shaftCollar, keyStock, rigidCoupler, flexibleCoupler, jawCoupler, leadScrew
gt2Belt, gt2Pulley, spurGear, rack
extensionSpring, torsionSpring
roundBar, squareBar, angleStock, squareHollowSection, rectangularHollowSection, tube
packageDIP, packageTO220, packageChip
brushedDCMotor, gearedDCMotor, nema17Stepper, hobbyServo, solenoid, relayPCB
thermalPad, thermalPaste
drillBit, endMill, latheInsert, sawBlade
thermocouple, rtdPT100, strainGauge, loadCell
batteryAA, batteryAAA, batteryCR2032, battery18650, batteryPP3
