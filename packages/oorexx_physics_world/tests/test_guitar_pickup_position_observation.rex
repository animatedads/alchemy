numeric digits 30
m=.GuitarStringPhysicalModel~new(82.4068892,.648,.00045,75,.00008,2.8,.018,5)
models=.array~of(m,.GuitarStringPhysicalModel~new(110),.GuitarStringPhysicalModel~new(146.832384),.GuitarStringPhysicalModel~new(195.997718),.GuitarStringPhysicalModel~new(246.941651),.GuitarStringPhysicalModel~new(329.627557))
body=.array~of(.GuitarBodyMode~new('body',170,.2,.03,.05,1))
g=.GuitarInstrumentFactory~standardSixString(models,.array~of(0,0,0,0,0,0),body,.GuitarBoundaryImpedance~new('bridge',1500,.1),.nil,1,.0008,.18)
c=g~course('E2')
yBridge=c~displacementAt(.82);yNeck=c~displacementAt(.70)
if yBridge=yNeck then exit 1
do i=1 to 200;g~step(.000005);end
if c~velocityAt(.82)=0 then exit 1
say 'PHYSICS GUITAR PICKUP-POSITION OBSERVATION: OK y82=' yBridge 'y70=' yNeck
::requires 'GuitarInstrumentMechanics.cls'
