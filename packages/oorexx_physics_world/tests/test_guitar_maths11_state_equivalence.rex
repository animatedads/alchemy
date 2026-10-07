numeric digits 30
models=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557)
 models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,5))
end
frets=.array~of(0,0,0,0,0,0)
body=.array~of(.GuitarBodyMode~new('body-165',165,.20,.025,.05,1),.GuitarBodyMode~new('body-330',330,.12,.035,.03,.7))
bridge=.GuitarBoundaryImpedance~new('bridge',1800,.18,1,'fixture');nut=.GuitarBoundaryImpedance~new('nut',8000,.10,1,'fixture')
g=.GuitarInstrumentFactory~standardSixString(models,frets,body,bridge,nut,1,.0008,.18)
p=.GuitarMathsDynamicsProjection~new(g,.MathContext~binary64('SCIPY'))
call time 'R'; state=p~advanceInstrument(.0000025,1200,.nil,'SYMPLECTIC_EULER'); native=time('E')
g2=.GuitarInstrumentFactory~standardSixString(models,frets,body,bridge,nut,1,.0008,.18)
call time 'R';do s=1 to 1200;g2~step(.0000025);end;scalar=time('E')
maxX=0;maxV=0;i=0
do c over g2~courses
 do q over c~oscillators
  i+=1;dx=abs(q~displacement-state~displacement[i]);dv=abs(q~velocity-state~velocity[i]);if dx>maxX then maxX=dx;if dv>maxV then maxV=dv
 end
end
do b over g2~bodyModes
 i+=1;dx=abs(b~displacement-state~displacement[i]);dv=abs(b~velocity-state~velocity[i]);if dx>maxX then maxX=dx;if dv>maxV then maxV=dv
end
if maxX>2E-10 | maxV>2E-7 then exit 1
say 'PHYSICS GUITAR MATHS11 STATE EQUIVALENCE: OK'
say 'scalarSeconds=' scalar 'nativeSeconds=' native 'speedup=' scalar/native
say 'maxX=' maxX 'maxV=' maxV
::requires 'GuitarMathsDynamics.cls'
