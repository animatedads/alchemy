numeric digits 50
m=.Units~q(2,.Units~kilogram)
a=.Units~q(3,.Units~metrePerSecondSquared)
f=m*a
if abs(f~in(.Units~newton)-6)>'0.0000001' then do; say 'FAIL: kg*m/s2 != N'; exit 1; end
force=.Units~q(10,.Units~newton)
time=.Units~q('0.5',.Units~second)
impulse=force*time
if abs(impulse~in(.Units~newtonSecond)-5)>'0.0000001' then do; say 'FAIL: N*s impulse'; exit 1; end
say 'PHYSICS MECHANICS UNITS: OK'
::requires 'Mechanics.cls'
