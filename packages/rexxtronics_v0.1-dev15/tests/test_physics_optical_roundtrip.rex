/* Optional full peer-integration qualification.
 *
 * Requires:
 *   MATHS_REXX   -> ooRexx Maths v0.8 rexx/
 *   Physics dev4 -> bundled under deps, or REXXTRONICS_PHYSICS_ROOT override
 *
 * This exercises a real Physics OpticalBeamProbe; it is not a Rexx-tronics
 * stub of optical propagation.
 */
numeric digits 50
failures = 0

/* Electrical emitter: 10 V, variable series resistance, 100-ohm lamp.
 * At VR minimum the lamp dissipates 0.25 W and the evidence curve says 2 cd.
 */
lp = .array~new
lp~append(.PowerIntensityPoint~new('0 W', .Units~q(0, .Units~candela)))
lp~append(.PowerIntensityPoint~new('0.01 W', .Units~q(0.1, .Units~candela)))
lp~append(.PowerIntensityPoint~new('0.25 W', .Units~q(2, .Units~candela)))
lp~append(.PowerIntensityPoint~new('1 W', .Units~q(4, .Units~candela)))
lampCurve = .PowerIntensityCurve~new(lp)

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '10 V'))
vr = c~add(.VariableResistor~new('VR1', '100 Ohm', '900 Ohm', 0))
lamp = c~add(.PhotometricLamp~new('L1', '100 Ohm', lampCurve, 5, '2 W'))

sp = .array~new
sp~append(.LightResistancePoint~new(.Units~q(0, .Units~lux), '1 Mohm'))
sp~append(.LightResistancePoint~new(.Units~q(1000, .Units~lux), '10 kohm'))
sp~append(.LightResistancePoint~new(.Units~q(5000, .Units~lux), '1 kohm'))
ldrCurve = .LightResistanceCurve~new(sp)
ldr = c~add(.PhotoResistor~new('LDR1', ldrCurve, .Units~q(1000, .Units~lux)))

senseR = c~add(.Resistor~new('R_SENSE', '10 kohm'))
c~connect('VCC', .array~of(v~positive, vr~pin('A'), senseR~pin('A')))
c~connect('LAMP_RETURN', .array~of(vr~pin('B'), lamp~pin('A')))
c~connect('SENSE', .array~of(senseR~pin('B'), ldr~pin('A')))
c~connectGround(lamp~pin('B'))
c~connectGround(ldr~pin('B'))
c~connectGround(v~negative)

initial = c~solveDC
call near lamp~power~in(.Units~watt), 0.25, 'electrical lamp power'
call near lamp~luminousIntensity~in(.Units~candela), 2, 'electrical->photometric transfer'

/* Physics World direct path: 1 cm square sensor at 2 cm. */
ctx = .MathContext~decimal(40)
world = .PhysicalWorld~new(.OpticalMedium~air)
sourcePose = .PhysicalPose~new(.MathVector3~new(0,0,0,ctx), .nil, ctx)
sensorPose = .PhysicalPose~new(.MathVector3~new(0,0,0.02,ctx), .nil, ctx)
probe = .OpticalBeamProbe~new(world, sourcePose, sensorPose, 0.01, 0.01, 555, 1, 'LDR-optical-aperture')
bridge = .PhysicsBeamIlluminanceAdapter~new(probe, lamp)

obs = bridge~sampleAndApply(ldr, '1 ms', 'lamp direct path')
call near obs~illuminance~in(.Units~lux), '4708.60048', 'Physics exact rectangular illuminance'
if obs~evidence~transmission~canonicalValue <> 1 then do
  say 'FAIL direct Physics transmission was not 1'
  failures += 1
end
afterLight = c~solveDC
if afterLight~voltageQuantity('SENSE')~in(.Units~volt) >= initial~voltageQuantity('SENSE')~in(.Units~volt) then do
  say 'FAIL photoresistor circuit did not respond to Physics illuminance'
  failures += 1
end

/* Add an opaque body halfway to the sensor.  Physics, not Rexx-tronics,
 * decides the beam is blocked.
 */
brick = .OpticalBody~new('blocker', .BoxShape~new(0.02,0.02,0.005,ctx), .PhysicsMaterials~blackAbsorber, -
    .PhysicalPose~new(.MathVector3~new(0,0,0.01,ctx), .nil, ctx))
world~addBody(brick)
blocked = bridge~sample('2 ms', 'opaque blocker inserted')
call near blocked~illuminance~in(.Units~lux), 0, 'Physics occlusion illuminance'
call near blocked~evidence~transmission~canonicalValue, 0, 'Physics occlusion transmission'

if failures = 0 then do
  say 'REXX-TRONICS / PHYSICS OPTICAL ROUND TRIP: OK'
  say 'lamp power:' lamp~power~in(.Units~watt) 'W'
  say 'lamp intensity:' lamp~luminousIntensity~in(.Units~candela) 'cd'
  say 'direct sensor:' obs~illuminance~in(.Units~lux) 'lx'
  say 'blocked sensor:' blocked~illuminance~in(.Units~lux) 'lx'
  exit 0
end
say 'FAIL Physics round-trip failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label
  if abs(actual - expected) > '0.0001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures += 1
  end
  return

::requires 'RexxTronicsPhysics.cls'
