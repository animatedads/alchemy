numeric digits 30
rho=.PhysicsQuantity~new('1.2',.SI~kilogramPerCubicMetre)
c=.PhysicsQuantity~new(340,.SI~metrePerSecond)
z=rho*c
call near z~in(.SI~pascalSecondPerMetre),408,'density * sound speed = acoustic impedance','0.0000001'
p=.PhysicsQuantity~new(20,.SI~microPascal)
call near p~in(.SI~pascal),'0.00002','20 uPa pressure reference','0.0000000001'
f=.PhysicsQuantity~new(1000,.SI~hertz)
if f~dimension~canonical<>((.PhysicsDimension~dimensionless/.PhysicsDimension~time)~canonical) then do; say 'FAIL hertz dimension'; exit 1; end
say 'PHYSICS ACOUSTICS UNITS: OK'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'Acoustics.cls'
