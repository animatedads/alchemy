numeric digits 30
a=.array~of(-10,0,10)
cl=.AerodynamicCoefficientTable1D~new(a,.array~of(-.5,0,.5))
cd=.AerodynamicCoefficientTable1D~new(a,.array~of(.08,.02,.08))
cm=.AerodynamicCoefficientTable1D~new(a,.array~of(.1,0,-.1))
m=.LongitudinalAerodynamicTableModel~new(cl,cd,cm,20,2)
s=.AerodynamicOperatingState~new(5,0,.2,100,1)
o=m~evaluate(s)
if o~dynamicPressure<>5000 | o~lift<>25000 | o~drag<>5000 | o~pitchMoment<>-10000 then exit 1
say 'PHYSICS AERO TABLE FORCES: OK q=' o~dynamicPressure 'lift=' o~lift 'drag=' o~drag 'moment=' o~pitchMoment
::requires 'AerodynamicCoefficientTables.cls'
