/* Optional proof/certification providers backed by existing Python libraries
 * through ooRexx Foreign Runtime. Public mathematical meaning remains in Maths.cls.
 */
ignored=.Maths~registerProvider(.MathSympyProvider~new)
ignored=.Maths~registerProvider(.MathMpmathIntervalProvider~new)
if .ForeignPython~canImport('flint') then ignored=.Maths~registerProvider(.MathFlintBallProvider~new)

::class MathSympyProvider subclass MathProvider public
::method init
  expose _helper _version _pythonVersion _providerPath
  if \.ForeignPython~canImport('oorexx_maths_proof') then raise syntax 88.900 array('importable oorexx_maths_proof helper','not available on PYTHONPATH')
  if \.ForeignPython~canImport('sympy') then raise syntax 88.900 array('importable sympy','not available')
  _helper=.ForeignPython~import('oorexx_maths_proof')
  sp=.ForeignPython~import('sympy'); _version=sp~get('__version__'); _pythonVersion=sp~pythonVersion; _providerPath=sp~providerPath; sp~close
::method name; return 'SYMPY'
::method version; expose _version; return _version
::method supports; use strict arg operation; return operation='expression.prove.equals'
::method _assumptionsDict
  use strict arg assumptions
  top=.ForeignPython~dict
  facts=assumptions~facts
  grouped=.directory~new
  do key over facts~allIndexes
    parse var key vname ':' prop
    if \grouped~hasIndex(vname) then grouped[vname]=.directory~new
    grouped[vname][prop~lower]=facts[key]
  end
  do var over grouped~allIndexes
    d=.ForeignPython~dict
    do prop over grouped[var]~allIndexes; d~put(prop,grouped[var][prop]); end
    top~put(var,d)
  end
  return top
::method proveEquals
  expose _helper _pythonVersion _providerPath
  use strict arg expression,claim,assumptions
  expected=.MathExpression~coerce(claim~expected,expression~context)
  ad=self~_assumptionsDict(assumptions)
  raw=_helper~sympy_prove_equal(.ForeignPython~text(expression~providerText),.ForeignPython~text(expected~providerText),ad)
  ev=.MathEvidence~new('expression.prove.equals',expression~context,.array~of(expression~canonical,expected~canonical))
  details='python='_pythonVersion';module='_providerPath';method='raw['method']
  ev~addStep(.MathPathStep~new('expression.prove.equals',self~name,self~version,'symbolic-identity-check','SYMBOLIC','exact symbolic','SymPy expression',details,'EXACT_IF_SYMBOLIC_ZERO','SYMPY,SYMBOLIC'))
  checks=.directory~new; checks['simplifiedDifference']=raw['simplified_difference']; checks['equalsAdvisory']=raw['equals_advisory']
  notes=.array~of('PROVED is emitted only when SymPy simplification reduces the claimed difference exactly to zero. Expr.equals() is retained only as advisory evidence because it may use numerical probing.')
  outcome=raw['outcome']
  if outcome='PROVED' then strength='SYMBOLICALLY_PROVED'
  else if outcome='DISPROVED' then strength='DISPROVED'
  else strength='UNVERIFIED'
  return .MathProof~new(strength,ev,.nil,checks,notes,claim,assumptions,outcome)
::method uninit
  expose _helper
  if symbol('_helper')='VAR' then if _helper \== .nil then _helper~close


::class MathMpmathIntervalProvider subclass MathProvider public
::method init
  expose _helper _version _pythonVersion _providerPath
  if \.ForeignPython~canImport('oorexx_maths_proof') then raise syntax 88.900 array('importable oorexx_maths_proof helper','not available on PYTHONPATH')
  if \.ForeignPython~canImport('mpmath') then raise syntax 88.900 array('importable mpmath','not available')
  _helper=.ForeignPython~import('oorexx_maths_proof')
  mp=.ForeignPython~import('mpmath'); _version=mp~get('__version__'); _pythonVersion=mp~pythonVersion; _providerPath=mp~providerPath; mp~close
::method name; return 'MPMATH-IV'
::method version; expose _version; return _version
::method supports; use strict arg operation; return operation='expression.interval'
::method intervalEvaluate
  expose _helper _pythonVersion _providerPath
  use strict arg expression,bounds,context
  bd=.ForeignPython~dict; boundText=''; names=bounds~allIndexes; names~sort
  do name over names
    pair=bounds[name]
    if \pair~isA(.array) | pair~items<>2 then raise syntax 88.900 array('two-element interval Array for 'name,pair)
    bd~put(name,.array~of(pair[1]~string,pair[2]~string))
    if boundText<>'' then boundText=boundText','
    boundText=boundText||name'=['pair[1]','pair[2]']'
  end
  raw=_helper~mpmath_interval_eval(.ForeignPython~text(expression~providerText),bd,context~requestedDigits)
  ev=.MathEvidence~new('expression.interval',context,.array~of(expression~canonical,'bounds{'boundText'}'))
  details='python='_pythonVersion';module='_providerPath';method='raw['method']
  ev~addStep(.MathPathStep~new('expression.interval',self~name,self~version,'interval-expression-evaluation','ARBITRARY_PRECISION_BINARY_INTERVAL',context~requestedDigits,'mpmath.iv interval',details,'RIGOROUS_CONTAINMENT_FOR_SUPPORTED_DIRECT_ARITHMETIC','MPMATH,INTERVAL'))
  ev~addWarning('Interval containment does not imply a tight bound. Repeated dependent variables can cause severe over-enclosure; proof strength must state the actual claim.')
  ev~addWarning('v0.7 uses mpmath.iv only for direct arithmetic expression evaluation. It does not generalise interval certification to unsupported/experimental mpmath.iv algorithms such as root finding.')
  ev~putCheck('width',raw['width'])
  return .MathInterval~new(raw['lower'],raw['upper'],raw['width'],raw['enclosure'],context,ev)
::method uninit
  expose _helper
  if symbol('_helper')='VAR' then if _helper \== .nil then _helper~close


::class MathFlintBallProvider subclass MathProvider public
::method init
  expose _helper _version _pythonVersion _providerPath
  if \.ForeignPython~canImport('oorexx_maths_proof') then raise syntax 88.900 array('importable oorexx_maths_proof helper','not available on PYTHONPATH')
  if \.ForeignPython~canImport('flint') then raise syntax 88.900 array('importable python-flint','not available')
  _helper=.ForeignPython~import('oorexx_maths_proof')
  fp=.ForeignPython~import('flint'); _version=fp~get('__version__'); _pythonVersion=fp~pythonVersion; _providerPath=fp~providerPath; fp~close
  if rx_math_version_at_least(_version,'0.9.0')=0 then raise syntax 88.900 array('python-flint >= 0.9.0 (known arb.neg fix required)',_version)
::method name; return 'FLINT-ARB'
::method version; expose _version; return _version
::method supports; use strict arg operation; return operation='expression.ball'
::method ballEvaluate
  expose _helper _pythonVersion _providerPath
  use strict arg expression,bounds,context
  bd=.ForeignPython~dict; boundText=''; names=bounds~allIndexes; names~sort
  do name over names
    pair=bounds[name]
    if \pair~isA(.array) | pair~items<>2 then raise syntax 88.900 array('two-element ball interval Array for 'name,pair)
    bd~put(name,.array~of(pair[1]~string,pair[2]~string))
    if boundText<>'' then boundText=boundText','
    boundText=boundText||name'=['pair[1]','pair[2]']'
  end
  raw=_helper~flint_ball_eval(.ForeignPython~text(expression~providerText),bd,context~requestedDigits)
  ev=.MathEvidence~new('expression.ball',context,.array~of(expression~canonical,'bounds{'boundText'}'))
  details='python='_pythonVersion';module='_providerPath';method='raw['method']';certificate=mid:'raw['certificate_mid']',rad:'raw['certificate_rad']',exp10:'raw['certificate_exp10']
  ev~addStep(.MathPathStep~new('expression.ball',self~name,self~version,'arb-ball-expression-evaluation','ARBITRARY_PRECISION_BALL',context~requestedDigits,'Arb midpoint-radius ball',details,'RIGOROUS_BALL_ENCLOSURE','PYTHON-FLINT,ARB,BALL'))
  ev~addWarning('Arb inclusion certifies containment for the supported operation path; it does not imply that the resulting ball is tight enough for a stronger accuracy claim.')
  ev~putCheck('certificateMid',raw['certificate_mid'])
  ev~putCheck('certificateRadius',raw['certificate_rad'])
  ev~putCheck('certificateExp10',raw['certificate_exp10'])
  ev~putCheck('relativeAccuracyBits',raw['relative_accuracy_bits'])
  ev~putCheck('isExact',raw['is_exact'])
  return .MathBall~new(raw['enclosure'],raw['relative_accuracy_bits'],raw['is_exact']='1',self~name,context,ev)
::method uninit
  expose _helper
  if symbol('_helper')='VAR' then if _helper \== .nil then _helper~close

::requires 'MathsBootstrap.cls'
::requires 'python_foreign.cls'
