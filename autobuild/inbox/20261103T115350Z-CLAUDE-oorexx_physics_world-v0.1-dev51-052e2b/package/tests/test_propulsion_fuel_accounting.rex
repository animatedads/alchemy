numeric digits 30
m=.LinearStaticThrustMap~new(100000,1,1.225); e=.PropulsionUnit~new(m)
op=.PropulsionOperatingPoint~new(.5,0,1.225)
o=e~step(10,op)
if o~thrust<>50000 | o~fuelIncrement<>5 | o~totalFuel<>5 then exit 1
say 'PHYSICS PROPULSION FUEL ACCOUNTING: OK thrust=' o~thrust 'fuel=' o~totalFuel
::requires 'Propulsion.cls'
