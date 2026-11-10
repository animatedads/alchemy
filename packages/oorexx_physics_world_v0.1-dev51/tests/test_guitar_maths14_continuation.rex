numeric digits 30
/* Monolithic reference instrument. */
models1=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557)
 models1~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,5))
end
frets=.array~of(0,0,0,0,0,0)
body1=.array~of(.GuitarBodyMode~new('body-165',165,.20,.025,.05,1),.GuitarBodyMode~new('body-330',330,.12,.035,.03,.7))
bridge1=.GuitarBoundaryImpedance~new('bridge',1800,.18,1,'fixture');nut1=.GuitarBoundaryImpedance~new('nut',8000,.10,1,'fixture')
g1=.GuitarInstrumentFactory~standardSixString(models1,frets,body1,bridge1,nut1,1,.0008,.18)
ctx=.MathContext~binary64('SCIPY')
p1=.GuitarMathsDynamicsProjection~new(g1,ctx)
mono=p1~integrateFinal(.0000025,1200,.nil,'SYMPLECTIC_EULER')

/* Same physical topology, advanced through Maths v0.14 continuation blocks. */
models2=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557)
 models2~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,5))
end
body2=.array~of(.GuitarBodyMode~new('body-165',165,.20,.025,.05,1),.GuitarBodyMode~new('body-330',330,.12,.035,.03,.7))
bridge2=.GuitarBoundaryImpedance~new('bridge',1800,.18,1,'fixture');nut2=.GuitarBoundaryImpedance~new('nut',8000,.10,1,'fixture')
g2=.GuitarInstrumentFactory~standardSixString(models2,frets,body2,bridge2,nut2,1,.0008,.18)
p2=.GuitarMathsDynamicsProjection~new(g2,ctx)
cont=p2~continuation('SYMPLECTIC_EULER')
do block=1 to 12
 tr=p2~advanceContinuationBlock(cont,.0000025,100)
 if tr~evidence~primaryProvider<>'SCIPY' then do; say 'FAIL provider' tr~evidence~primaryProvider; exit 1; end
end
final=cont~lastState
if abs(cont~time-.003)>1E-14 then do; say 'FAIL time' cont~time; exit 1; end
maxX=0;maxV=0
do i=1 to p2~dimension
 dx=abs(final~displacement[i]-mono~displacement[i]); if dx>maxX then maxX=dx
 dv=abs(final~velocity[i]-mono~velocity[i]); if dv>maxV then maxV=dv
end
if maxX>2E-10 | maxV>2E-7 then do; say 'FAIL state' maxX maxV; exit 1; end
if abs(g2~time-.003)>1E-14 then do; say 'FAIL instrument time' g2~time; exit 1; end
if g2~ledger~items<>12 then do; say 'FAIL ledger items' g2~ledger~items; exit 1; end

/* v0.14 delay continuation is checkpointable and deterministic. */
d=.Maths~sampleDelayLine(4,0,ctx)
a=.array~new
do x over .array~of(1,2,3,4,5,6); a~append(d~push(x)); end
snap=d~snapshot
r1=d~push(7); r2=d~push(8)
d~restore(snap)
if abs(d~push(7)-r1)>1E-15 | abs(d~push(8)-r2)>1E-15 then do; say 'FAIL delay restore'; exit 1; end
say 'PHYSICS GUITAR MATHS14 CONTINUATION: OK'
say 'blocks=12 stepsPerBlock=100 maxX='maxX 'maxV='maxV 'time='cont~time
say 'delayFirstOutputs=' a[1] a[2] a[3] a[4] a[5] a[6]
::requires 'GuitarMathsDynamics.cls'
