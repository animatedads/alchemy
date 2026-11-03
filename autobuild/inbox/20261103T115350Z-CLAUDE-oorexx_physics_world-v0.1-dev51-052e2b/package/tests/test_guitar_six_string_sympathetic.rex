numeric digits 30
models=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557)
 models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,5))
end
frets=.array~of(0,0,0,0,0,0)
body=.array~of(.GuitarBodyMode~new('body-165',165,.20,.025,.05,1),.GuitarBodyMode~new('body-330',330,.12,.035,.03,.7))
bridge=.GuitarBoundaryImpedance~new('bridge',1800,.18,1,'fixture')
nut=.GuitarBoundaryImpedance~new('nut',8000,.10,1,'fixture')
g=.GuitarInstrumentFactory~standardSixString(models,frets,body,bridge,nut,1,.0008,.18)
silent0=g~course('E4')~mechanicalEnergy
maxSilent=silent0
initial=g~totalMechanicalEnergy
do i=1 to 1200
 g~step(.0000025)
 e=g~course('E4')~mechanicalEnergy
 if e>maxSilent then maxSilent=e
end
if silent0<>0 then exit 1
if maxSilent<=0 then exit 1
if g~course('E2')~mechanicalEnergy<=0 then exit 1
say 'PHYSICS GUITAR SIX-STRING SYMPATHETIC: OK initialJ=' initial 'silentE4maxJ=' maxSilent
::requires 'GuitarInstrumentMechanics.cls'
