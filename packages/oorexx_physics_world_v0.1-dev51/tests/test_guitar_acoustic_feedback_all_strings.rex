numeric digits 30
models=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557)
 models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,2))
end
body=.array~of(.GuitarBodyMode~new('body',180,.2,.03,.05,1))
g=.GuitarInstrumentFactory~standardSixString(models,.array~of(0,0,0,0,0,0),body,.GuitarBoundaryImpedance~new('bridge',900,.08),.nil,0,0,.18)
d=.GuitarAcousticFeedbackDriver~new(g,.GuitarAcousticForceCoupling~new(.000002,.045,1,1,'fixture'))
obs=.GuitarAcousticPressureObservation~new(0,.1,'monitor','direct path','fixture')
d~step(.00001,obs)
do c over g~courses
 if c~mechanicalEnergy<=0 then do
   say 'FAIL acoustically silent course' c~name
   exit 1
 end
end
if g~bodyModes[1]~mechanicalEnergy<=0 then exit 1
say 'PHYSICS GUITAR ACOUSTIC FEEDBACK ALL STRINGS: OK'
::requires 'GuitarAcousticFeedback.cls'
