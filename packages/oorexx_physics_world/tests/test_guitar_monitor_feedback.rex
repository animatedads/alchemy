numeric digits 30
models=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557)
 models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,3))
end
body=.array~of(.GuitarBodyMode~new('body-170',170,.20,.03,.05,1))
bridge=.GuitarBoundaryImpedance~new('bridge',1200,.12,1,'fixture')
g=.GuitarInstrumentFactory~standardSixString(models,.array~of(0,0,0,0,0,0),body,bridge,.nil,1,.0008,.18)
driver=.GuitarAcousticFeedbackDriver~new(g,.GuitarAcousticForceCoupling~new(.000002,.045,1,1,'fixture pressure coupling'))
silent0=g~course('B3')~mechanicalEnergy
pi=4*RxCalcArcTan(1,30,'R')
maxSilent=silent0
do i=0 to 399
 t=i*.00001
 pressure=.02*RxCalcSin(2*pi*246.941651*t,30,'R')
 obs=.GuitarAcousticPressureObservation~new(t,pressure,'monitor-speaker','speaker -> air -> guitar','fixture')
 driver~step(.00001,obs)
 e=g~course('B3')~mechanicalEnergy
 if e>maxSilent then maxSilent=e
end
if silent0<>0 then exit 1
if maxSilent<=0 then exit 1
if driver~ledger~items<>400 then exit 1
say 'PHYSICS GUITAR MONITOR FEEDBACK: OK silentInitialJ=' silent0 'silentMaxJ=' maxSilent
::requires 'GuitarAcousticFeedback.cls'
