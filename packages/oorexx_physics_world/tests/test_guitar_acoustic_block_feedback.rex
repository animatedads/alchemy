numeric digits 30
ctx=.MathContext~decimal(30,'PURE'); models=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557); models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,3)); end
frets=.array~of(0,0,0,0,0,0); body=.array~of(.GuitarBodyMode~new('body-165',165,.20,.025,.05,1),.GuitarBodyMode~new('body-330',330,.12,.035,.03,.7))
g=.GuitarInstrumentFactory~standardSixString(models,frets,body,.GuitarBoundaryImpedance~new('bridge',1800,.18,1,'fixture'),.GuitarBoundaryImpedance~new('nut',8000,.10,1,'fixture'),1,0,.18)
proj=.GuitarMathsDynamicsProjection~new(g,ctx); driver=.GuitarAcousticBlockFeedbackDriver~new(proj,.GuitarAcousticForceCoupling~new(.000002,.045,1,1,'fixture'))
p=.array~new
do i=0 to 100; p~append(.12*RxCalcSin(2*.Maths~pi(ctx)*220*i*.0000025,30,'R')); end
ev=driver~advancePressureBlock(.0000025,p,'speaker->air->guitar','monitor'); energy=0
do c over g~courses; do q over c~oscillators; energy+=q~mechanicalEnergy; end; end
do b over g~bodyModes; energy+=b~mechanicalEnergy; end
if ev['STEPS']<>100 | energy<=0 then exit 1
say 'PHYSICS GUITAR ACOUSTIC BLOCK FEEDBACK: OK'; say 'dof='proj~dimension 'energy='energy 'time='g~time
::requires 'rxmath' LIBRARY
::requires 'GuitarAcousticBlockFeedback.cls'
