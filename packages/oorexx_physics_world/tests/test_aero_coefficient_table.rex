numeric digits 30
x=.array~of(-10,0,10); y=.array~of(-.5,0,.5)
t=.AerodynamicCoefficientTable1D~new(x,y)
if t~evaluate(5)<>.25 then exit 1
say 'PHYSICS AERO COEFFICIENT TABLE: OK value=' t~evaluate(5)
::requires 'AerodynamicCoefficientTables.cls'
