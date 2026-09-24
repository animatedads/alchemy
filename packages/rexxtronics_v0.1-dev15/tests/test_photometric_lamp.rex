/* Qualification: electrical power from the accepted DC solve drives a
 * datasheet/model-backed luminous-intensity curve.  No generic lamp law is
 * invented.
 */
numeric digits 50
failures = 0

points = .array~new
points~append(.PowerIntensityPoint~new('0 W', .Units~q(0, .Units~candela)))
points~append(.PowerIntensityPoint~new('0.01 W', .Units~q(0.1, .Units~candela)))
points~append(.PowerIntensityPoint~new('0.25 W', .Units~q(2, .Units~candela)))
points~append(.PowerIntensityPoint~new('1 W', .Units~q(4, .Units~candela)))
curve = .PowerIntensityCurve~new(points)

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '10 V'))
vr = c~add(.VariableResistor~new('VR1', '100 Ohm', '900 Ohm', 0))
lamp = c~add(.PhotometricLamp~new('L1', '100 Ohm', curve, 5, '2 W'))

c~connect('VCC', .array~of(v~positive, vr~pin('A')))
c~connect('MID', .array~of(vr~pin('B'), lamp~pin('A')))
c~connectGround(lamp~pin('B'))
c~connectGround(v~negative)

s1 = c~solveDC
call near lamp~power~in(.Units~watt), 0.25, 'low series resistance lamp power'
call near lamp~luminousIntensity~in(.Units~candela), 2, 'low series resistance lamp intensity'

vr~setPosition(1)
s2 = c~solveDC
call near lamp~power~in(.Units~watt), 0.01, 'high series resistance lamp power'
call near lamp~luminousIntensity~in(.Units~candela), 0.1, 'high series resistance lamp intensity'

if failures = 0 then do
  say 'REXX-TRONICS PHOTOMETRIC LAMP: OK'
  say 'VR low: power=' s1~powerQuantity(lamp)~in(.Units~watt) 'W intensity=2 cd'
  say 'VR high: power=' s2~powerQuantity(lamp)~in(.Units~watt) 'W intensity=0.1 cd'
  exit 0
end
say 'FAIL photometric lamp failures='failures
exit 1

near: procedure expose failures
  use arg actual, expected, label
  if abs(actual - expected) > '0.0000001' then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures += 1
  end
  return

::requires 'RexxTronicsPhysical.cls'
