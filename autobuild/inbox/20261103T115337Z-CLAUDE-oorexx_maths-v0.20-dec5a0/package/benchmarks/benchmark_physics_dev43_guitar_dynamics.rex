numeric digits 30
/* Build the current Physics dev43 six-string fixture. */
models=.array~new
do f over .array~of(82.4068892,110,146.832384,195.997718,246.941651,329.627557)
 models~append(.GuitarStringPhysicalModel~new(f,.648,.00045,75,.00008,2.8,.018,5))
end
frets=.array~of(0,0,0,0,0,0)
body=.array~of(.GuitarBodyMode~new('body-165',165,.20,.025,.05,1),.GuitarBodyMode~new('body-330',330,.12,.035,.03,.7))
bridge=.GuitarBoundaryImpedance~new('bridge',1800,.18,1,'fixture')
nut=.GuitarBoundaryImpedance~new('nut',8000,.10,1,'fixture')
g=.GuitarInstrumentFactory~standardSixString(models,frets,body,bridge,nut,1,.0008,.18)

/* Project Physics-owned oscillator semantics into generic M,C,K. */
dofs=.array~new; starts=.array~new; counts=.array~new; x0=.array~new; v0=.array~new
idx=0
do c over g~courses
 starts~append(idx+1); cc=0
 do q over c~oscillators
   idx+=1;cc+=1;dofs~append(q);x0~append(q~displacement);v0~append(q~velocity)
 end
 counts~append(cc)
end
bodyStart=idx+1
do b over g~bodyModes
 idx+=1;dofs~append(b);x0~append(b~displacement);v0~append(b~velocity)
end
nDof=idx
M=.array~new; C=.array~new; K=.array~new
do i=1 to nDof
 mr=.array~new;cr=.array~new;kr=.array~new
 do j=1 to nDof;mr~append(0);cr~append(0);kr~append(0);end
 M~append(mr);C~append(cr);K~append(kr)
end
do i=1 to nDof
 q=dofs[i];M[i][i]=q~mass;C[i][i]+=q~dampingCoefficient;K[i][i]+=q~stiffness
end
pi=4*RxCalcArcTan(1,30,'R'); p=bridge~participation
courses=g~courses; nCourses=courses~items
do ci=1 to nCourses
 start=starts[ci]; cnt=counts[ci]
 shapes=.array~new; nutShapes=.array~new
 do mi=1 to cnt
   shapes~append(RxCalcSin(pi*mi*.999,30,'R'))
   nutShapes~append(RxCalcSin(pi*mi*.001,30,'R'))
 end
 do mi=1 to cnt
   i=start+mi-1; si=shapes[mi]
   do mj=1 to cnt
     j=start+mj-1; sj=shapes[mj]
     K[i][j]+=bridge~stiffness*si*sj
     C[i][j]+=bridge~damping*si*sj
   end
   if nut<>.nil then do
     ns=nutShapes[mi]
     K[i][i]+=nut~stiffness*ns*ns
     C[i][i]+=nut~damping*ns*ns
   end
   do bidx=bodyStart to nDof
     term=bridge~stiffness*si*p; damp=bridge~damping*si*p
     K[i][bidx]-=term;K[bidx][i]-=term
     C[i][bidx]-=damp;C[bidx][i]-=damp
   end
 end
end
do bi=bodyStart to nDof
 do bj=bodyStart to nDof
   K[bi][bj]+=nCourses*p*p*bridge~stiffness
   C[bi][bj]+=nCourses*p*p*bridge~damping
 end
end

ctx=.MathContext~binary64('SCIPY')
sys=.Maths~secondOrderSystem(M,C,K,ctx)
call time 'R'
final=sys~integrateFinal(x0,v0,.0000025,1200,.nil,0,'SYMPLECTIC_EULER')
nativeElapsed=time('E')

/* Run the actual Physics loop from a fresh fixture. */
g2=.GuitarInstrumentFactory~standardSixString(models,frets,body,bridge,nut,1,.0008,.18)
call time 'R'
do s=1 to 1200; g2~step(.0000025); end
physicsElapsed=time('E')
maxX=0;maxV=0;i=0
do c over g2~courses
 do q over c~oscillators
   i+=1;dx=(q~displacement-final~displacement[i])~abs;dv=(q~velocity-final~velocity[i])~abs
   if dx>maxX then maxX=dx;if dv>maxV then maxV=dv
 end
end
do b over g2~bodyModes
 i+=1;dx=(b~displacement-final~displacement[i])~abs;dv=(b~velocity-final~velocity[i])~abs
 if dx>maxX then maxX=dx;if dv>maxV then maxV=dv
end
say 'PHYSICS_SECONDS='physicsElapsed
say 'MATHS_NATIVE_SECONDS='nativeElapsed
say 'SPEEDUP='physicsElapsed/nativeElapsed
say 'MAX_X_DIFF='maxX
say 'MAX_V_DIFF='maxV
say 'EQUILIBRIUM_RESIDUAL='final~evidence~checks['equilibriumResidualInf']
say 'KINEMATIC_X_RESIDUAL='final~evidence~checks['kinematicDisplacementResidualInf']
say 'KINEMATIC_V_RESIDUAL='final~evidence~checks['kinematicVelocityResidualInf']
if maxX>2E-10 | maxV>2E-7 then exit 1
say 'PASS Physics dev43 six-string state-equivalent Maths native symplectic projection'
::requires 'MathDynamicsProvider.cls'
::requires 'GuitarInstrumentMechanics.cls'
