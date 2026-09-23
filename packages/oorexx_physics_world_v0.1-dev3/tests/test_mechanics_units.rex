numeric digits 20
m=.PhysicsQuantity~new(2,.SI~kilogram)
a=.PhysicsQuantity~new(3,.SI~metrePerSecondSquared)
f=m*a
if abs(f~in(.SI~newton)-6)>'0.0000001' then do; say 'FAIL: kg*m/s2 != N'; exit 1; end
force=.PhysicsQuantity~new(10,.SI~newton)
time=.PhysicsQuantity~new('0.5',.SI~second)
impulse=force*time
if abs(impulse~in(.SI~newtonSecond)-5)>'0.0000001' then do; say 'FAIL: N*s impulse'; exit 1; end
say 'PHYSICS MECHANICS UNITS: OK'
::requires 'Mechanics.cls'
