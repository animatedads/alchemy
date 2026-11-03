/* Optional accelerated second-order dynamics provider.
 * Public mathematical meaning remains in Maths.cls.  This provider executes
 * constant-coefficient Newmark average-acceleration blocks through SciPy/NumPy
 * using Foreign Runtime, and retains residual/conditioning evidence.
 */
numpyReady=.ForeignPython~canImport('numpy')
if numpyReady then do
  scipyReady=.ForeignPython~canImport('scipy')
  if scipyReady then do
    helperReady=.ForeignPython~canImport('oorexx_maths_native')
    if helperReady then ignored=.Maths~registerProvider(.MathScipyDynamicsProvider~new)
  end
end

::class MathScipyDynamicsProvider subclass MathNumpyProvider public
::method init
  expose _native _scipyVersion _scipyPath _npDyn
  self~init:super
  _native=.ForeignPython~import('oorexx_maths_native')
  _npDyn=.ForeignPython~import('numpy')
  sp=.ForeignPython~import('scipy')
  _scipyVersion=sp~get('__version__'); _scipyPath=sp~providerPath
  sp~close
::method name; return 'SCIPY'
::method version; expose _scipyVersion; return _scipyVersion
::method supports
  use strict arg operation
  if operation='dynamics.second-order.integrate' | operation='dynamics.second-order.final' | operation='dynamics.second-order.io' then return .true
  return self~supports:super(operation)
::method secondOrderIntegrate
  expose _native _scipyVersion _scipyPath _npDyn _pythonVersion _providerPath _blasName _blasVersion _lapackName _lapackVersion
  use strict arg system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for SCIPY dynamics provider',context~canonical)
  if forces==.nil then forceArg=.nil
  else if forces~isA(.MathVector) then forceArg=forces~toArray
  else if forces~isA(.MathMatrix) then do
    if forces~rows<>steps+1 | forces~cols<>system~dimension then raise syntax 88.900 array('force-history matrix shape '(steps+1)'x'system~dimension,forces~rows'x'forces~cols)
    forceArg=forces~toArray
  end
  else do
    fh=rx_math_second_order_force_history(forces,steps,system~dimension,context); forceArg=fh~toArray
  end
  raw=_native~integrate_second_order(system~massMatrix~toArray,system~dampingMatrix~toArray,system~stiffnessMatrix~toArray, -
       initialDisplacement~toArray,initialVelocity~toArray,dt,steps,forceArg,method)
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  timesA=_npDyn~array(raw['times'],kw); xA=_npDyn~array(raw['displacement'],kw); vA=_npDyn~array(raw['velocity'],kw); aA=_npDyn~array(raw['acceleration'],kw)
  times=self~_float64List(timesA); do ti=1 to times~items; times[ti]=times[ti]+startTime; end; xs=self~_float64List(xA); vs=self~_float64List(vA); accs=self~_float64List(aA)
  timesA~close; xA~close; vA~close; aA~close
  stack='python='_pythonVersion';numpy='_providerPath';scipy='_scipyPath' '_scipyVersion';BLAS='_blasName' '_blasVersion';LAPACK='_lapackName' '_lapackVersion
  ev=.MathEvidence~new('dynamics.second-order.integrate',context,.array~of(system~canonical,'dt='dt,'steps='steps,'t0='startTime))
  ev~addStep(.MathPathStep~new('dynamics.second-order.integrate',self~name,self~version,raw['algorithm'],'BINARY64',16,'SciPy/NumPy float64 trajectory',stack';solver='raw['solver'],'APPROXIMATE_IEEE754','SCIPY,NUMPY,BLAS,LAPACK,NEWMARK,LU-FACTOR-REUSE'))
  ev~addWarning('The accelerated path is binary64. Proof/corroboration must use the retained reference route when stronger precision is required.')
  ev~putCheck('equilibriumResidualInf',raw['equilibrium_residual_inf'])
  ev~putCheck('kinematicDisplacementResidualInf',raw['kinematic_displacement_residual_inf'])
  ev~putCheck('kinematicVelocityResidualInf',raw['kinematic_velocity_residual_inf'])
  ev~putCheck('conditionMass',raw['condition_mass'])
  ev~putCheck('conditionEffective',raw['condition_effective'])
  deriv=.MathDerivation~new('dynamics.second-order.integrate',.array~of(system,initialDisplacement,initialVelocity,dt,steps,forces,startTime),method)
  return .MathSecondOrderTrajectory~new(times,xs,vs,accs,dt,startTime,context,ev,deriv)
::method secondOrderIntegrateProjected
  expose _native _scipyVersion _scipyPath _npDyn _pythonVersion _providerPath _blasName _blasVersion _lapackName _lapackVersion
  use strict arg io,initialDisplacement,initialVelocity,dt,steps,inputs,startTime,method,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for SCIPY projected dynamics provider',context~canonical)
  m=io~inputCount
  if inputs==.nil then inputArg=.nil
  else if inputs~isA(.MathMatrix) then do
    if inputs~rows<>steps+1 | inputs~cols<>m then raise syntax 88.900 array('input-history matrix shape '(steps+1)'x'm,inputs~rows'x'inputs~cols)
    inputArg=inputs~toArray
  end
  else if inputs~isA(.MathVector) & m=1 then do
    if inputs~size<>steps+1 then raise syntax 88.900 array('scalar input history length steps+1',steps+1,inputs~size)
    inputArg=inputs~toArray
  end
  else inputArg=inputs
  sys=io~system
  raw=_native~integrate_second_order_projected(sys~massMatrix~toArray,sys~dampingMatrix~toArray,sys~stiffnessMatrix~toArray, -
       io~inputMatrix~toArray,io~displacementOutputMatrix~toArray,io~velocityOutputMatrix~toArray, -
       initialDisplacement~toArray,initialVelocity~toArray,dt,steps,inputArg,method)
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  timesA=_npDyn~array(raw['times'],kw); outA=_npDyn~array(raw['outputs'],kw); xA=_npDyn~array(raw['final_displacement'],kw); vA=_npDyn~array(raw['final_velocity'],kw); aA=_npDyn~array(raw['final_acceleration'],kw)
  times=self~_float64List(timesA); do ti=1 to times~items; times[ti]=times[ti]+startTime; end
  ys=self~_float64List(outA); xs=self~_float64List(xA); vs=self~_float64List(vA); accs=self~_float64List(aA)
  timesA~close; outA~close; xA~close; vA~close; aA~close
  stack='python='_pythonVersion';numpy='_providerPath';scipy='_scipyPath' '_scipyVersion';BLAS='_blasName' '_blasVersion';LAPACK='_lapackName' '_lapackVersion
  ev=.MathEvidence~new('dynamics.second-order.io',context,.array~of(io~canonical,'dt='dt,'steps='steps,'t0='startTime))
  ev~addStep(.MathPathStep~new('dynamics.second-order.io',self~name,self~version,raw['algorithm'],'BINARY64',16,'SciPy/NumPy selected-channel trajectory',stack';solver='raw['solver'],'APPROXIMATE_IEEE754','SCIPY,NUMPY,BLAS,LAPACK,SECOND-ORDER,INPUT-OUTPUT,PROJECTION'))
  ev~putCheck('equilibriumResidualInf',raw['equilibrium_residual_inf']); ev~putCheck('kinematicDisplacementResidualInf',raw['kinematic_displacement_residual_inf']); ev~putCheck('kinematicVelocityResidualInf',raw['kinematic_velocity_residual_inf'])
  ev~putCheck('conditionMass',raw['condition_mass']); ev~putCheck('conditionEffective',raw['condition_effective'])
  final=.MathSecondOrderState~new(startTime+steps*dt,.MathVector~new(xs,context,ev),.MathVector~new(vs,context,ev),.MathVector~new(accs,context,ev),context,ev)
  return .MathSecondOrderProjectedTrajectory~new(times,ys,final,dt,startTime,context,ev,.MathDerivation~new('dynamics.second-order.io',.array~of(io,initialDisplacement,initialVelocity,dt,steps,inputs,startTime),method))

::method secondOrderIntegrateFinal
  expose _native _scipyVersion _scipyPath _npDyn _pythonVersion _providerPath _blasName _blasVersion _lapackName _lapackVersion
  use strict arg system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context
  numeric digits context~workingDigits
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 context for SCIPY dynamics provider',context~canonical)
  if forces==.nil then forceArg=.nil
  else if forces~isA(.MathVector) then forceArg=forces~toArray
  else if forces~isA(.MathMatrix) then do
    if forces~rows<>steps+1 | forces~cols<>system~dimension then raise syntax 88.900 array('force-history matrix shape '(steps+1)'x'system~dimension,forces~rows'x'forces~cols)
    forceArg=forces~toArray
  end
  else do
    fh=rx_math_second_order_force_history(forces,steps,system~dimension,context); forceArg=fh~toArray
  end
  raw=_native~integrate_second_order(system~massMatrix~toArray,system~dampingMatrix~toArray,system~stiffnessMatrix~toArray, -
       initialDisplacement~toArray,initialVelocity~toArray,dt,steps,forceArg,method,.25,.5,.false)
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  xA=_npDyn~array(raw['displacement'],kw); vA=_npDyn~array(raw['velocity'],kw); aA=_npDyn~array(raw['acceleration'],kw)
  xs=self~_float64List(xA); vs=self~_float64List(vA); accs=self~_float64List(aA); xA~close; vA~close; aA~close
  stack='python='_pythonVersion';numpy='_providerPath';scipy='_scipyPath' '_scipyVersion';BLAS='_blasName' '_blasVersion';LAPACK='_lapackName' '_lapackVersion
  ev=.MathEvidence~new('dynamics.second-order.final',context,.array~of(system~canonical,'dt='dt,'steps='steps,'t0='startTime))
  ev~addStep(.MathPathStep~new('dynamics.second-order.final',self~name,self~version,raw['algorithm'],'BINARY64',16,'SciPy/NumPy float64 final state',stack';solver='raw['solver'],'APPROXIMATE_IEEE754','SCIPY,NUMPY,BLAS,LAPACK,SECOND-ORDER,LU-FACTOR-REUSE'))
  ev~putCheck('equilibriumResidualInf',raw['equilibrium_residual_inf']); ev~putCheck('kinematicDisplacementResidualInf',raw['kinematic_displacement_residual_inf']); ev~putCheck('kinematicVelocityResidualInf',raw['kinematic_velocity_residual_inf'])
  ev~putCheck('conditionMass',raw['condition_mass']); ev~putCheck('conditionEffective',raw['condition_effective'])
  deriv=.MathDerivation~new('dynamics.second-order.final',.array~of(system,initialDisplacement,initialVelocity,dt,steps,forces,startTime),method)
  finalTime=startTime+steps*dt
  return .MathSecondOrderState~new(finalTime,.MathVector~new(xs,context,ev),.MathVector~new(vs,context,ev),.MathVector~new(accs,context,ev),context,ev,deriv)

::method uninit
  expose _native _npDyn
  if symbol('_native')='VAR' then if _native \== .nil then _native~close
  if symbol('_npDyn')='VAR' then if _npDyn \== .nil then _npDyn~close
  self~uninit:super

::requires 'MathNumpyProvider.cls'
::requires 'python_foreign.cls'
