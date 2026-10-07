t=.AerodynamicCoefficientTable1D~new(.array~of(-10,0,10),.array~of(-.5,0,.5))
signal on syntax name bad
x=t~evaluate(20)
exit 1
bad:
say 'PHYSICS AERO TABLE DOMAIN FAIL-CLOSED: OK'
exit 0
::requires 'AerodynamicCoefficientTables.cls'
