m=.LinearStaticThrustMap~new(100000,1,1.225); e=.PropulsionUnit~new(m)
a=e~step(1,.PropulsionOperatingPoint~new(1,0,1.225)); b=e~step(1,.PropulsionOperatingPoint~new(1,0,.6125))
if abs(b~thrust-a~thrust/2)>.000001 then exit 1
say 'PHYSICS PROPULSION DENSITY RESPONSE: OK sea=' a~thrust 'halfDensity=' b~thrust
::requires 'Propulsion.cls'
