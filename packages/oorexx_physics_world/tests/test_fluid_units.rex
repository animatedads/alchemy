numeric digits 30
water=.FluidMedium~new( -
  'typed-water', -
  .Units~q('0.9982',.Units~gramPerCubicCentimetre), -
  .Units~q('0.001002',.Units~pascal*.Units~second))
call near water~density,'998.2','typed density'
call near water~dynamicViscosity,'0.001002','typed viscosity','0.000000000001'
call near water~densityQuantity~in(.Units~gramPerCubicCentimetre),'0.9982','density display','0.000000001'
call near water~kinematicViscosityQuantity~in(.Units~squareMetre/.Units~second), -
  '0.000001003806852334202','kinematic viscosity','0.000000000000001'
q=.FluidDynamics~dynamicPressureQuantity(water,.Units~q(3,.Units~metrePerSecond))
call near q~in(.Units~pascal),'4491.9','dynamic pressure'
call expectBadViscosity
say 'PHYSICS FLUID SHARED UNITS: OK'
exit 0
expectBadViscosity: procedure
  signal on syntax name expected
  bad=.FluidMedium~new('bad',1000,.Units~q(2,.Units~metre))
  say 'FAIL length accepted as viscosity'; exit 1
expected:
  return
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Fluids.cls'
