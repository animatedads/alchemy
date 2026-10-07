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
ctx=.MathContext~binary64('SCIPY')
projection=.GuitarMathsDynamicsProjection~new(g,ctx)
if projection~dimension<>32 then exit 1
call time 'R'
state=projection~advanceInstrument(.0000025,1200,.nil,'SYMPLECTIC_EULER')
elapsed=time('E')
if abs(g~time-.003)>1E-15 then exit 1
if state~evidence~primaryProvider<>'SCIPY' then exit 1
if g~ledger~items<>1 then exit 1
say 'PHYSICS GUITAR MATHS11 DYNAMICS: OK provider=' state~evidence~primaryProvider 'dimension=' projection~dimension 'seconds=' elapsed
say 'equilibriumResidual=' state~evidence~checks['equilibriumResidualInf']
::requires 'GuitarMathsDynamics.cls'
