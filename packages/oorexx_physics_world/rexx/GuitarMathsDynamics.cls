/* Physics World v0.1-dev45
 * Physics-owned projection of the coupled guitar into Maths v0.11 generic
 * M*x'' + C*x' + K*x = f dynamics. Maths owns propagation, not topology.
 */
numeric digits 30

::class GuitarMathsDynamicsProjection public
::method init
 expose _instrument _context _system _dofs _x0 _v0
 use strict arg instrument,context
 _instrument=instrument;_context=context
 built=self~buildSystem
 _system=built['SYSTEM'];_dofs=built['DOFS'];_x0=built['X0'];_v0=built['V0']
::method system; expose _system; return _system
::method dimension; expose _dofs; return _dofs~items
::method context; expose _context; return _context
::method initialDisplacement; expose _x0; return _x0~copy
::method initialVelocity; expose _v0; return _v0~copy

::method continuation
 expose _system _x0 _v0 _instrument
 use strict arg method='SYMPLECTIC_EULER'
 return .Maths~secondOrderContinuation(_system,_x0,_v0,_instrument~time,method)

::method continuationFromCurrentState
 expose _system _dofs _instrument
 use strict arg method='SYMPLECTIC_EULER'
 x=.array~new;v=.array~new
 do q over _dofs; x~append(q~displacement); v~append(q~velocity); end
 return .Maths~secondOrderContinuation(_system,x,v,_instrument~time,method)

::method buildSystem
 expose _instrument _context
 courses=_instrument~courses; body=_instrument~bodyModes
 bridge=_instrument~bridgeImpedance; nut=_instrument~nutImpedance
 dofs=.array~new;starts=.array~new;counts=.array~new;x0=.array~new;v0=.array~new
 idx=0
 do c over courses
   starts~append(idx+1);cc=0
   do q over c~oscillators
     idx+=1;cc+=1;dofs~append(q);x0~append(q~displacement);v0~append(q~velocity)
   end
   counts~append(cc)
 end
 bodyStart=idx+1
 do b over body
   idx+=1;dofs~append(b);x0~append(b~displacement);v0~append(b~velocity)
 end
 nDof=idx
 M=.array~new;C=.array~new;K=.array~new
 do i=1 to nDof
   mr=.array~new;cr=.array~new;kr=.array~new
   do j=1 to nDof;mr~append(0);cr~append(0);kr~append(0);end
   M~append(mr);C~append(cr);K~append(kr)
 end
 do i=1 to nDof
   q=dofs[i];M[i][i]=q~mass;C[i][i]+=q~dampingCoefficient;K[i][i]+=q~stiffness
 end
 pi=.Maths~pi(_context);p=bridge~participation;nCourses=courses~items
 do ci=1 to nCourses
   start=starts[ci];cnt=counts[ci];shapes=.array~new;nutShapes=.array~new
   do mi=1 to cnt
     shapes~append(RxCalcSin(pi*mi*.999,30,'R'))
     nutShapes~append(RxCalcSin(pi*mi*.001,30,'R'))
   end
   do mi=1 to cnt
     i=start+mi-1;si=shapes[mi]
     do mj=1 to cnt
       j=start+mj-1;sj=shapes[mj]
       K[i][j]+=bridge~stiffness*si*sj;C[i][j]+=bridge~damping*si*sj
     end
     if nut<>.nil then do
       ns=nutShapes[mi];K[i][i]+=nut~stiffness*ns*ns;C[i][i]+=nut~damping*ns*ns
     end
     do bidx=bodyStart to nDof
       term=bridge~stiffness*si*p;damp=bridge~damping*si*p
       K[i][bidx]-=term;K[bidx][i]-=term;C[i][bidx]-=damp;C[bidx][i]-=damp
     end
   end
 end
 do bi=bodyStart to nDof
   do bj=bodyStart to nDof
     K[bi][bj]+=nCourses*p*p*bridge~stiffness;C[bi][bj]+=nCourses*p*p*bridge~damping
   end
 end
 out=.directory~new
 out['SYSTEM']=.Maths~secondOrderSystem(M,C,K,_context);out['DOFS']=dofs;out['X0']=x0;out['V0']=v0
 return out

::method acousticForceVector
 expose _instrument _context
 use strict arg pressurePa,forceCoupling
 out=.array~new; pi=.Maths~pi(_context)
 do c over _instrument~courses
   n=0
   do q over c~oscillators
     n+=1
     out~append(forceCoupling~stringForce(pressurePa,2/(pi*n)))
   end
 end
 do b over _instrument~bodyModes; out~append(forceCoupling~bodyForce(pressurePa,1)); end
 if out~items<>self~dimension then raise syntax 88.900 array('acoustic force vector matching dynamics dimension',self~dimension)
 return .MathVector~new(out,_context)
::method acousticForceHistory
 expose _context
 use strict arg pressureSamples,forceCoupling
 rows=.array~new
 do pressurePa over pressureSamples; rows~append(self~acousticForceVector(pressurePa,forceCoupling)~toArray); end
 return .MathMatrix~new(rows,_context)

::method integrateFinal
 expose _system _x0 _v0 _instrument
 use strict arg dt,steps,forces=.nil,method='SYMPLECTIC_EULER'
 return _system~integrateFinal(_x0,_v0,dt,steps,forces,_instrument~time,method)

::method advanceInstrument
 expose _dofs _instrument
 use strict arg dt,steps,forces=.nil,method='SYMPLECTIC_EULER'
 state=self~integrateFinal(dt,steps,forces,method)
 do i=1 to _dofs~items
   _dofs[i]~setState(state~displacement[i],state~velocity[i])
 end
 _instrument~setTime(state~time)
 _instrument~recordDynamicsEvidence(state~evidence,dt,steps,method)
 return state

::method advanceContinuationBlock
 expose _dofs _instrument
 use strict arg continuation,dt,steps,forces=.nil
 trajectory=continuation~advance(dt,steps,forces)
 state=trajectory~finalState
 do i=1 to _dofs~items
   _dofs[i]~setState(state~displacement[i],state~velocity[i])
 end
 _instrument~setTime(state~time)
 _instrument~recordDynamicsEvidence(state~evidence,dt,steps,continuation~method)
 return trajectory

::requires 'rxmath' LIBRARY
::requires 'MathDynamicsProvider.cls'
::requires 'GuitarInstrumentMechanics.cls'
