/* Qualification: a Physics observation is sampled when simulation time reaches
 * the scheduled instant, after earlier geometry changes on the same clock.
 */
numeric digits 50
failures = 0

/* Electrical side: 5 V pull-up, photoresistor to ground. */
c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '5 V'))
r = c~add(.Resistor~new('R_SENSE', '10 kohm'))
pts = .array~new
pts~append(.LightResistancePoint~new(.Units~q(0, .Units~lux), '1 Mohm'))
pts~append(.LightResistancePoint~new(.Units~q(1000, .Units~lux), '10 kohm'))
pts~append(.LightResistancePoint~new(.Units~q(5000, .Units~lux), '1 kohm'))
curve = .LightResistanceCurve~new(pts)
ldr = c~add(.PhotoResistor~new('LDR1', curve, .Units~q(1000, .Units~lux)))
c~connect('VCC', .array~of(v~positive, r~pin('A')))
c~connect('SENSE', .array~of(r~pin('B'), ldr~pin('A')))
c~connectGround(ldr~pin('B'))
c~connectGround(v~negative)

/* A fixed 2 cd optical source at 2 cm from a 1 cm square sensor. */
powerPts = .array~new
powerPts~append(.PowerIntensityPoint~new('0 W', .Units~q(0, .Units~candela)))
powerPts~append(.PowerIntensityPoint~new('0.25 W', .Units~q(2, .Units~candela)))
lampCurve = .PowerIntensityCurve~new(powerPts)
lamp = .PhotometricLamp~new('L1', '100 Ohm', lampCurve, 5, '2 W')
/* Set electrical power deterministically through a tiny source circuit. */
emit = .Circuit~new
ev = emit~add(.DCVoltageSource~new('EV', '5 V'))
emit~add(lamp)
emit~connect('EVCC', .array~of(ev~positive, lamp~pin('A')))
emit~connectGround(lamp~pin('B')); emit~connectGround(ev~negative)
emit~solveDC
call near lamp~power~in(.Units~watt), 0.25, 'lamp power'

ctx = .MathContext~decimal(40)
world = .PhysicalWorld~new(.OpticalMedium~air)
sourcePose = .PhysicalPose~new(.MathVector3~new(0,0,0,ctx), .nil, ctx)
sensorPose = .PhysicalPose~new(.MathVector3~new(0,0,0.02,ctx), .nil, ctx)
probe = .OpticalBeamProbe~new(world, sourcePose, sensorPose, 0.01, 0.01, 555, 1, 'scheduled-LDR')
bridge = .PhysicsBeamIlluminanceAdapter~new(probe, lamp)

/* Prove the path is initially open. */
openObs = bridge~sampleAndApply(ldr, '0 ms', 'initial open path')
if openObs~illuminance~in(.Units~lux) <= 0 then do
  say 'FAIL initial Physics path should be illuminated'
  failures += 1
end
initial = c~solveDC

/* The blocker is inserted at t=1 ms.  The optical sample itself occurs at
 * t=2 ms, so it must observe the then-current Physics world, not a value
 * precomputed when the event was scheduled.
 */
brick = .OpticalBody~new('scheduled-blocker', .BoxShape~new(0.02,0.02,0.005,ctx), .PhysicsMaterials~blackAbsorber, -
    .PhysicalPose~new(.MathVector3~new(0,0,0.01,ctx), .nil, ctx))
clock = .SimulationClock~new
clock~scheduleAt('1 ms', world, 'ADDBODY', .array~of(brick), 'insert optical blocker')
bridge~scheduleSample(clock, '2 ms', ldr, 'sample after blocker')
clock~runUntil('2 ms')

obs = ldr~lastObservation
if obs == .nil then do
  say 'FAIL scheduled Physics observation was not applied'
  failures += 1
end
else do
  call near obs~illuminance~in(.Units~lux), 0, 'blocked scheduled illuminance'
  call near obs~time~in(.Units~millisecond), 2, 'observation simulation time'
  if obs~cause <> 'sample after blocker' then do
    say 'FAIL scheduled cause provenance mismatch:' obs~cause
    failures += 1
  end
  if obs~evidence~transmission~canonicalValue <> 0 then do
    say 'FAIL scheduled Physics transmission should be zero'
    failures += 1
  end
end

after = c~solveDC
if after~voltageQuantity('SENSE')~in(.Units~volt) <= initial~voltageQuantity('SENSE')~in(.Units~volt) then do
  say 'FAIL blocked photoresistor circuit should drive SENSE upward'
  failures += 1
end

if failures = 0 then do
  say 'REXX-TRONICS / PHYSICS SCHEDULED SAMPLING: OK'
  say 'initial lux:' openObs~illuminance~in(.Units~lux)
  say 'scheduled lux:' obs~illuminance~in(.Units~lux)
  say 'scheduled time ms:' obs~time~in(.Units~millisecond)
  say 'SENSE before:' initial~voltageQuantity('SENSE')~in(.Units~volt) 'V'
  say 'SENSE after:' after~voltageQuantity('SENSE')~in(.Units~volt) 'V'
  exit 0
end
say 'FAIL Physics scheduled sampling failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label
  if abs(actual - expected) > '0.0001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures += 1
  end
  return

::requires 'RexxTronicsPhysics.cls'
