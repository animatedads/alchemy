/* oorexx_maths v0.7
 * Provider-neutral mathematical objects with explicit precision, evidence,
 * derivation and independent recomputation support.
 */

if \.local~hasIndex('OOREXX_MATHS_PROVIDERS') then .local['OOREXX_MATHS_PROVIDERS'] = .directory~new

::class Maths public
::method version class
  return '0.7'

::method defaultContext class
  return .MathContext~decimal(50)

::method registerProvider class
  use strict arg provider
  .local['OOREXX_MATHS_PROVIDERS'][provider~name~upper] = provider
  return provider

::method provider class
  use strict arg name
  key = name~string~upper
  providers = .local['OOREXX_MATHS_PROVIDERS']
  if \providers~hasIndex(key) then return .nil
  return providers[key]

::method providers class
  out = .array~new
  do p over .local['OOREXX_MATHS_PROVIDERS']
    out~append(p~name)
  end
  return out

::method providerFor class
  use strict arg context, operation=''
  requested = context~provider~upper
  if requested = 'AUTO' then do
    if context~numberDomain = 'BINARY64' then do
      p = self~provider('NUMPY')
      if p \== .nil then return p
    end
    return self~provider('PURE')
  end
  p = self~provider(requested)
  if p == .nil then raise syntax 88.900 array('registered maths provider', requested)
  if operation <> '' then if \p~supports(operation) then raise syntax 88.900 array('provider supporting 'operation, requested)
  return p

::method matrix class
  use strict arg data, context=.nil
  if context == .nil then context = self~defaultContext
  return .MathMatrix~new(data, context)

::method vector class
  use strict arg data, context=.nil
  if context == .nil then context = self~defaultContext
  return .MathVector~new(data, context)

::method complex class
  use strict arg real=0, imaginary=0, context=.nil
  if context == .nil then context = self~defaultContext
  return .MathComplex~new(real, imaginary, context)

::method identity class
  use strict arg n, context=.nil
  if context == .nil then context = self~defaultContext
  return .MathMatrix~identity(n, context)

::method variable class
  use strict arg name, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathVariable~new(name,context)

::method constant class
  use strict arg value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathConstant~new(value,context)

::method assumptions class
  return .MathAssumptions~new

::method integer class
  use strict arg value, context=.nil
  if context == .nil then context=.MathContext~rational
  return .MathInteger~new(value,context)

::method fraction class
  use strict arg numerator, denominator, context=.nil
  if context == .nil then context=.MathContext~rational
  return .MathRational~of(numerator,denominator,context)

::method rational class
  use strict arg numerator, denominator=1, context=.nil
  if context == .nil then context=.MathContext~rational
  return .MathRational~of(numerator,denominator,context)

::method exact class
  use strict arg value, context=.nil
  if context == .nil then context=.MathContext~rational
  if value~isA(.MathExactNumber) then return value
  text=value~string~strip
  if text~pos('(')>0 | text~pos(')')>0 then return .MathRational~fromRepeatingDecimal(text,context)
  slash=text~pos('/')
  if slash>0 then do
    if text~substr(slash+1)~pos('/')>0 then raise syntax 88.900 array('single exact fraction literal',text)
    return .MathRational~of(text~left(slash-1)~strip,text~substr(slash+1)~strip,context)
  end
  return .MathRational~fromDecimal(text,context)

::method decimalExpansion class
  use strict arg value, maxDigits=10000, context=.nil
  if context == .nil then context=.MathContext~rational
  return .MathRational~coerce(value,context)~decimalExpansion(maxDigits)

::method rationalFromDecimal class
  use strict arg text, context=.nil
  if context == .nil then context=.MathContext~rational
  return .MathRational~fromDecimal(text,context)

::method rationalMatrix class
  use strict arg data
  return .MathMatrix~new(data,.MathContext~rational)

::method rationalVector class
  use strict arg data
  return .MathVector~new(data,.MathContext~rational)

::method dtype class
  use strict arg name
  return .MathDType~of(name)

::method quantization class
  use strict arg name='INT8', blockSize=64, computeType='FLOAT32', nested=.false
  key=name~string~upper
  select
    when key='INT8' | key='SYMMETRIC_INT8' then return .MathQuantizationScheme~int8(blockSize,computeType)
    when key='NF4' then return .MathQuantizationScheme~nf4(blockSize,computeType,nested)
    otherwise raise syntax 88.900 array('INT8 or NF4 quantization scheme',name)
  end

::method quantize class
  use strict arg value, scheme=.nil
  if scheme == .nil then scheme=.MathQuantizationScheme~int8
  return .MathQuantizer~quantize(value,scheme)

::method mixedPrecision class
  use strict arg defaultScheme=.nil, minimumElements=4096, highPrecisionType='FLOAT32'
  if defaultScheme == .nil then defaultScheme=.MathQuantizationScheme~int8
  return .MathMixedPrecisionPlan~new(defaultScheme,minimumElements,highPrecisionType)

::method planProof class
  use strict arg value, claim=.nil, assumptions=.nil, policy=.nil
  return .MathProofPlanner~plan(value,claim,assumptions,policy)

::method prove class
  use strict arg value, claim=.nil, assumptions=.nil, policy=.nil
  return .MathProofPlanner~prove(value,claim,assumptions,policy)


::class MathContext public
::method init
  expose _requestedDigits _guardDigits _numberDomain _provider _lossPolicy _relativeTolerance _absoluteTolerance _verificationExtraDigits
  use strict arg requestedDigits=50, guardDigits=10, numberDomain='DECIMAL', provider='PURE', lossPolicy='FORBID', relativeTolerance='1E-40', absoluteTolerance='1E-45', verificationExtraDigits=20
  if \datatype(requestedDigits,'W') | requestedDigits < 1 then raise syntax 88.900 array('positive requested digits', requestedDigits)
  if \datatype(guardDigits,'W') | guardDigits < 0 then raise syntax 88.900 array('non-negative guard digits', guardDigits)
  _requestedDigits=requestedDigits
  _guardDigits=guardDigits
  _numberDomain=numberDomain~upper
  _provider=provider~upper
  _lossPolicy=lossPolicy~upper
  _relativeTolerance=relativeTolerance
  _absoluteTolerance=absoluteTolerance
  _verificationExtraDigits=verificationExtraDigits

::method requestedDigits; expose _requestedDigits; return _requestedDigits
::method guardDigits; expose _guardDigits; return _guardDigits
::method workingDigits; expose _requestedDigits _guardDigits; return _requestedDigits + _guardDigits
::method numberDomain; expose _numberDomain; return _numberDomain
::method provider; expose _provider; return _provider
::method lossPolicy; expose _lossPolicy; return _lossPolicy
::method relativeTolerance; expose _relativeTolerance; return _relativeTolerance
::method absoluteTolerance; expose _absoluteTolerance; return _absoluteTolerance
::method verificationExtraDigits; expose _verificationExtraDigits; return _verificationExtraDigits

::method decimal class
  use strict arg digits=50, provider='PURE'
  guard = 10
  relPlaces = digits - 10
  if relPlaces < 8 then relPlaces = 8
  absPlaces = digits - 5
  if absPlaces < 10 then absPlaces = 10
  rel = '1E-' || relPlaces
  abs = '1E-' || absPlaces
  return self~new(digits,guard,'DECIMAL',provider,'FORBID',rel,abs,20)

::method binary64 class
  use strict arg provider='NUMPY'
  return self~new(16,2,'BINARY64',provider,'ALLOW_EXPLICIT','1E-12','1E-14',40)

::method rational class
  use strict arg provider='PURE'
  return self~new(50,0,'RATIONAL',provider,'FORBID','0','0',0)

::method withProvider
  expose _requestedDigits _guardDigits _numberDomain _lossPolicy _relativeTolerance _absoluteTolerance _verificationExtraDigits
  use strict arg provider
  return self~class~new(_requestedDigits,_guardDigits,_numberDomain,provider,_lossPolicy,_relativeTolerance,_absoluteTolerance,_verificationExtraDigits)

::method verificationContext
  expose _requestedDigits _verificationExtraDigits _numberDomain
  if _numberDomain='RATIONAL' then return self~class~rational('REFERENCE')
  d = _requestedDigits + _verificationExtraDigits
  if d < 70 then d = 70
  return self~class~decimal(d,'REFERENCE')

::method canonical
  expose _requestedDigits _guardDigits _numberDomain _provider _lossPolicy _relativeTolerance _absoluteTolerance _verificationExtraDigits
  return 'digits='_requestedDigits';guard='_guardDigits';domain='_numberDomain';provider='_provider';loss='_lossPolicy';rtol='_relativeTolerance';atol='_absoluteTolerance';verifyExtra='_verificationExtraDigits

::method string
  return self~canonical


::class MathPathStep public
::method init
  expose _operation _provider _providerVersion _algorithm _numberDomain _workingDigits _representation _details _guarantee _independenceTags
  use strict arg operation, provider, providerVersion='', algorithm='', numberDomain='', workingDigits='', representation='', details='', guarantee='', independenceTags=''
  _operation=operation; _provider=provider; _providerVersion=providerVersion; _algorithm=algorithm
  _numberDomain=numberDomain; _workingDigits=workingDigits; _representation=representation; _details=details
  _guarantee=guarantee; _independenceTags=independenceTags
::method operation; expose _operation; return _operation
::method provider; expose _provider; return _provider
::method providerVersion; expose _providerVersion; return _providerVersion
::method algorithm; expose _algorithm; return _algorithm
::method numberDomain; expose _numberDomain; return _numberDomain
::method workingDigits; expose _workingDigits; return _workingDigits
::method representation; expose _representation; return _representation
::method details; expose _details; return _details
::method guarantee; expose _guarantee; return _guarantee
::method independenceTags; expose _independenceTags; return _independenceTags
::method canonical
  expose _operation _provider _providerVersion _algorithm _numberDomain _workingDigits _representation _details _guarantee _independenceTags
  return 'op='_operation';provider='_provider';version='_providerVersion';algorithm='_algorithm';domain='_numberDomain';digits='_workingDigits';repr='_representation';guarantee='_guarantee';independence='_independenceTags';details='_details
::method string; return self~canonical


::class MathEvidence public
::method init
  expose _operation _context _inputs _steps _warnings _checks _seal
  use strict arg operation, context, inputs=.nil
  _operation=operation; _context=context
  if inputs == .nil then _inputs=.array~new; else _inputs=inputs
  _steps=.array~new; _warnings=.array~new; _checks=.directory~new; _seal=.nil
::method operation; expose _operation; return _operation
::method context; expose _context; return _context
::method inputs; expose _inputs; return _inputs
::method steps; expose _steps; return _steps
::method warnings; expose _warnings; return _warnings
::method checks; expose _checks; return _checks
::method seal; expose _seal; return _seal
::method addStep
  expose _steps _seal
  use strict arg step
  _steps~append(step); _seal=.nil; return self
::method addWarning
  expose _warnings _seal
  use strict arg warning
  _warnings~append(warning); _seal=.nil; return self
::method putCheck
  expose _checks _seal
  use strict arg name,value
  _checks[name]=value; _seal=.nil; return self
::method attachSeal
  expose _seal
  use strict arg seal
  _seal=seal; return self
::method primaryProvider
  expose _steps
  if _steps~items=0 then return ''
  return _steps[1]~provider
::method canonical
  expose _operation _context _inputs _steps _warnings _checks
  s='MATH-EVIDENCE-v2|operation='_operation'|context={'_context~canonical'}'
  i=0
  do value over _inputs
    i+=1; s=s'|input['i']='value
  end
  i=0
  do step over _steps
    i+=1; s=s'|step['i']={'step~canonical'}'
  end
  i=0
  do warning over _warnings
    i+=1; s=s'|warning['i']='warning
  end
  names=_checks~allIndexes
  names~sort
  do name over names
    s=s'|check['name']='_checks[name]
  end
  return s
::method describe
  expose _operation _context _steps _warnings _checks _seal
  nl='0a'x
  s='operation: '_operation || nl || 'context: '_context~canonical
  do step over _steps
    s=s || nl || 'path: 'step~canonical
  end
  do warning over _warnings
    s=s || nl || 'warning: 'warning
  end
  names=_checks~allIndexes; names~sort
  do name over names
    s=s || nl || 'check: 'name'='_checks[name]
  end
  if _seal \== .nil then s=s || nl || 'seal: '_seal~canonical
  return s
::method string; return self~describe


::class MathSeal public
::method init
  expose _algorithm _digest _scope
  use strict arg algorithm,digest,scope='evidence-canonical-v1'
  _algorithm=algorithm; _digest=digest; _scope=scope
::method algorithm; expose _algorithm; return _algorithm
::method digest; expose _digest; return _digest
::method scope; expose _scope; return _scope
::method canonical; expose _algorithm _digest _scope; return 'algorithm='_algorithm';scope='_scope';digest='_digest
::method string; return self~canonical


::class MathDerivation public
::method init
  expose _operation _operands _parameter
  use strict arg operation, operands, parameter=.nil
  _operation=operation; _operands=operands; _parameter=parameter
::method operation; expose _operation; return _operation
::method operands; expose _operands; return _operands
::method parameter; expose _parameter; return _parameter


::class MathClaim public
::method init
  expose _kind _expected _parameter _description
  use strict arg kind, expected=.nil, parameter=.nil, description=''
  _kind=kind~upper; _expected=expected; _parameter=parameter; _description=description
::method kind; expose _kind; return _kind
::method expected; expose _expected; return _expected
::method parameter; expose _parameter; return _parameter
::method description; expose _description; return _description
::method independentlyReproduced class
  use strict arg tolerance=.nil
  return self~new('INDEPENDENT_REPRODUCTION',.nil,tolerance,'independent recomputation agrees within the applicable tolerance')
::method equals class
  use strict arg expected
  return self~new('EQUALS',expected,.nil,'expression/result equals the stated expected value')
::method satisfiesEquation class
  use strict arg tolerance=.nil
  return self~new('SATISFIES_EQUATION',.nil,tolerance,'derived solution satisfies its defining equation within the applicable tolerance')
::method accurateDigits class
  use strict arg digits
  if \datatype(digits,'W') | digits<1 then raise syntax 88.900 array('positive accuracy digits',digits)
  return self~new('ACCURATE_DIGITS',.nil,digits,'result is accurate to at least the stated decimal digits')
::method relativeAccuracyBits class
  use strict arg bits
  if \datatype(bits,'W') | bits<1 then raise syntax 88.900 array('positive relative accuracy bits',bits)
  return self~new('RELATIVE_ACCURACY_BITS',.nil,bits,'certified enclosure has at least the stated relative accuracy in bits')
::method isExact class
  return self~new('IS_EXACT',.nil,.nil,'value is represented exactly in its declared mathematical domain')
::method quantizationErrorBelow class
  use strict arg tolerance
  return self~new('QUANTIZATION_ERROR_BELOW',.nil,tolerance,'maximum absolute quantization reconstruction error is at or below tolerance over the retained represented source values')
::method enclosesExactEvaluation class
  return self~new('ENCLOSES_EXACT_EVALUATION',.nil,.nil,'reported interval encloses the exact evaluation for the stated input intervals and supported operation path')
::method contains class
  use strict arg value
  return self~new('CONTAINS',value,.nil,'reported interval contains the stated value')
::method canonical
  expose _kind _expected _parameter _description
  e=''; if _expected \== .nil then do
    if _expected~hasMethod('CANONICAL') then e=_expected~canonical; else e=_expected
  end
  p=''; if _parameter \== .nil then p=_parameter
  return 'kind='_kind';expected='e';parameter='p';description='_description
::method string; return self~canonical


::class MathAssumptions public
::method init; expose _facts; _facts=.directory~new
::method add
  expose _facts
  use strict arg variable, property, value=.true
  name=variable
  if variable~isA(.MathVariable) then name=variable~name
  key=name~string':'property~string~upper
  _facts[key]=value
  return self
::method real; use strict arg variable; self~add(variable,'REAL'); return self
::method positive; use strict arg variable; self~add(variable,'POSITIVE'); return self
::method nonnegative; use strict arg variable; self~add(variable,'NONNEGATIVE'); return self
::method nonzero; use strict arg variable; self~add(variable,'NONZERO'); return self
::method integer; use strict arg variable; self~add(variable,'INTEGER'); return self
::method has
  expose _facts
  use strict arg variable, property
  name=variable
  if variable~isA(.MathVariable) then name=variable~name
  return _facts~hasIndex(name~string':'property~string~upper)
::method facts; expose _facts; return _facts
::method canonical
  expose _facts
  names=_facts~allIndexes; names~sort; s=''
  first=.true
  do name over names
    if \first then s=s','; first=.false; s=s||name'='_facts[name]
  end
  return s
::method string; return self~canonical


::class MathProofPolicy public
::method init
  expose _name _runAll _requireCorroboration _certifiedOnly
  use strict arg name='STANDARD', runAll=.false, requireCorroboration=.false, certifiedOnly=.false
  _name=name~upper; _runAll=runAll; _requireCorroboration=requireCorroboration; _certifiedOnly=certifiedOnly
::method name; expose _name; return _name
::method runAll; expose _runAll; return _runAll
::method requireCorroboration; expose _requireCorroboration; return _requireCorroboration
::method certifiedOnly; expose _certifiedOnly; return _certifiedOnly
::method standard class; return self~new('STANDARD',.false,.false,.false)
::method strong class; return self~new('STRONG',.true,.true,.false)
::method certified class; return self~new('CERTIFIED',.true,.false,.true)
::method diagnostic class; return self~new('DIAGNOSTIC',.true,.false,.false)
::method canonical
  expose _name _runAll _requireCorroboration _certifiedOnly
  return 'name='_name';runAll='_runAll';requireCorroboration='_requireCorroboration';certifiedOnly='_certifiedOnly
::method string; return self~canonical

::class MathProofRoute public
::method init
  expose _id _role _provider _guarantee _independenceTags _reason _claim
  use strict arg id, role='OBLIGATION', provider='', guarantee='', independenceTags='', reason='', claim=.nil
  _id=id~upper; _role=role~upper; _provider=provider~upper; _guarantee=guarantee
  _independenceTags=independenceTags; _reason=reason; _claim=claim
::method id; expose _id; return _id
::method role; expose _role; return _role
::method provider; expose _provider; return _provider
::method guarantee; expose _guarantee; return _guarantee
::method independenceTags; expose _independenceTags; return _independenceTags
::method reason; expose _reason; return _reason
::method claim; expose _claim; return _claim
::method canonical
  expose _id _role _provider _guarantee _independenceTags _reason _claim
  c=''; if _claim \== .nil then c=_claim~canonical
  return 'id='_id';role='_role';provider='_provider';guarantee='_guarantee';independence='_independenceTags';claim={'c'};reason='_reason
::method string; return self~canonical

::class MathProofPlan public
::method init
  expose _claim _assumptions _policy _routes
  use strict arg claim, assumptions, policy
  _claim=claim; _assumptions=assumptions; _policy=policy; _routes=.array~new
::method claim; expose _claim; return _claim
::method assumptions; expose _assumptions; return _assumptions
::method policy; expose _policy; return _policy
::method routes; expose _routes; return _routes
::method addRoute
  expose _routes
  use strict arg route
  _routes~append(route); return self
::method routeCount; expose _routes; return _routes~items
::method canonical
  expose _claim _assumptions _policy _routes
  s='MATH-PROOF-PLAN-v1|claim={'_claim~canonical'}|assumptions={'_assumptions~canonical'}|policy={'_policy~canonical'}'
  i=0
  do r over _routes
    i+=1; s=s'|route['i']={'r~canonical'}'
  end
  return s
::method describe
  expose _claim _policy _routes
  nl='0a'x
  s='claim: '_claim~canonical || nl || 'policy: '_policy~canonical
  do r over _routes; s=s || nl || 'route: 'r~canonical; end
  return s
::method string; return self~describe

::class MathProofAttempt public
::method init
  expose _route _proof
  use strict arg route, proof
  _route=route; _proof=proof
::method route; expose _route; return _route
::method proof; expose _proof; return _proof
::method outcome; expose _proof; return _proof~outcome
::method strength; expose _proof; return _proof~status
::method canonical
  expose _route _proof
  return 'route={'_route~canonical'};proof={'_proof~canonical'}'
::method string; return self~canonical


::class MathProof public
::method init
  expose _status _outcome _claim _assumptions _primaryEvidence _verificationEvidence _checks _notes _plan _attempts _seal
  use strict arg status, primaryEvidence, verificationEvidence=.nil, checks=.nil, notes=.nil, claim=.nil, assumptions=.nil, outcome='', plan=.nil, attempts=.nil
  _status=status
  if outcome='' then do
    if status='VERIFIED_NUMERICALLY' | status='EXACT' | status='EXACTLY_REPRODUCED' | status='EXACT_BOUND_CERTIFIED' | status='INTERVAL_CERTIFIED' | status='BALL_CERTIFIED' | status='SYMBOLICALLY_PROVED' | status='NUMERICALLY_SATISFIED' then _outcome='PROVED'
    else if status='DISAGREEMENT' | status='DISPROVED' then _outcome='DISPROVED'
    else _outcome='INDETERMINATE'
  end
  else _outcome=outcome~upper
  _claim=claim; _assumptions=assumptions
  _primaryEvidence=primaryEvidence; _verificationEvidence=verificationEvidence
  if checks == .nil then _checks=.directory~new; else _checks=checks
  if notes == .nil then _notes=.array~new; else _notes=notes
  _plan=plan
  if attempts == .nil then _attempts=.array~new; else _attempts=attempts
  _seal=.nil
::method status; expose _status; return _status
::method strength; expose _status; return _status
::method outcome; expose _outcome; return _outcome
::method claim; expose _claim; return _claim
::method assumptions; expose _assumptions; return _assumptions
::method primaryEvidence; expose _primaryEvidence; return _primaryEvidence
::method verificationEvidence; expose _verificationEvidence; return _verificationEvidence
::method checks; expose _checks; return _checks
::method notes; expose _notes; return _notes
::method plan; expose _plan; return _plan
::method attempts; expose _attempts; return _attempts
::method seal; expose _seal; return _seal
::method attachSeal
  expose _seal
  use strict arg seal
  _seal=seal; return self
::method verified; expose _outcome; return _outcome='PROVED'
::method canonical
  expose _status _outcome _claim _assumptions _primaryEvidence _verificationEvidence _checks _notes _plan _attempts
  s='MATH-PROOF-v3|outcome='_outcome'|strength='_status
  if _claim \== .nil then s=s'|claim={'_claim~canonical'}'
  if _assumptions \== .nil then s=s'|assumptions={'_assumptions~canonical'}'
  if _plan \== .nil then s=s'|plan={'_plan~canonical'}'
  if _primaryEvidence \== .nil then s=s'|primary={'_primaryEvidence~canonical'}'
  if _verificationEvidence \== .nil then s=s'|verification={'_verificationEvidence~canonical'}'
  names=_checks~allIndexes; names~sort
  do name over names; s=s'|check['name']='_checks[name]; end
  i=0; do note over _notes; i+=1; s=s'|note['i']='note; end
  i=0; do attempt over _attempts; i+=1; s=s'|attempt['i']={'attempt~canonical'}'; end
  return s
::method describe
  expose _status _outcome _claim _assumptions _checks _notes _verificationEvidence _plan _attempts _seal
  nl='0a'x
  s='outcome: '_outcome || nl || 'strength: '_status
  if _claim \== .nil then s=s || nl || 'claim: '_claim~canonical
  if _assumptions \== .nil then s=s || nl || 'assumptions: '_assumptions~canonical
  if _plan \== .nil then s=s || nl || 'policy: '_plan~policy~name || nl || 'planned-routes: '_plan~routeCount
  names=_checks~allIndexes; names~sort
  do name over names; s=s || nl || name': '_checks[name]; end
  if _verificationEvidence \== .nil then s=s || nl || 'verification-provider: '_verificationEvidence~primaryProvider
  do attempt over _attempts; s=s || nl || 'attempt: 'attempt~route~id' -> 'attempt~outcome' / 'attempt~strength; end
  do note over _notes; s=s || nl || 'note: 'note; end
  if _seal \== .nil then s=s || nl || 'proof-seal: '_seal~canonical
  return s
::method string; return self~describe

::class MathValue public
::method init
  expose _context _evidence _derivation
  use strict arg context, evidence=.nil, derivation=.nil
  _context=context; _evidence=evidence; _derivation=derivation
::method context; expose _context; return _context
::method evidence; expose _evidence; return _evidence
::method provenance; expose _evidence; return _evidence
::method derivation; expose _derivation; return _derivation
::method _setEvidence
  expose _evidence; use strict arg evidence; _evidence=evidence; return self
::method _setDerivation
  expose _derivation; use strict arg derivation; _derivation=derivation; return self
::method prove
  use strict arg claim=.nil, assumptions=.nil, policy=.nil
  return .MathProofPlanner~prove(self,claim,assumptions,policy)
::method doAgainDifferently
  return .MathProofPlanner~recompute(self)


::class MathExactNumber subclass MathValue public
::method isExact; return .true
::method exactDomain; return 'EXACT'


::class MathRational subclass MathExactNumber public
::method init
  expose _numerator _denominator
  use strict arg numerator=0, denominator=1, context=.nil, evidence=.nil, derivation=.nil
  if context == .nil then context=.MathContext~rational
  self~init:super(context,evidence,derivation)
  pair=rx_math_normalize_fraction(numerator,denominator)
  _numerator=pair[1]; _denominator=pair[2]
  if evidence == .nil then do
    ev=.MathEvidence~new('rational.construct',context,.array~of(numerator~string,denominator~string))
    ev~addStep(.MathPathStep~new('rational.construct','PURE','0.7','integer-gcd-normalization','EXACT_RATIONAL','exact','normalized numerator/denominator','no floating-point conversion','EXACT','PURE,RATIONAL,INTEGER-GCD'))
    ev~putCheck('exact','1')
    ev~putCheck('canonical',self~string)
    self~_setEvidence(ev)
  end
::method of class
  use strict arg numerator=0, denominator=1, context=.nil, evidence=.nil, derivation=.nil
  if context == .nil then context=.MathContext~rational
  pair=rx_math_normalize_fraction(numerator,denominator)
  if pair[2]=1 then return .MathInteger~new(pair[1],context,evidence,derivation)
  return .MathFraction~new(pair[1],pair[2],context,evidence,derivation)
::method numerator; expose _numerator; return _numerator
::method denominator; expose _denominator; return _denominator
::method isInteger; expose _denominator; return _denominator=1
::method isRational; return .true
::method isFraction; expose _denominator; return _denominator<>1
::method canonical
  expose _numerator _denominator
  if _denominator=1 then return 'integer['_numerator']'
  return 'rational['_numerator'/'_denominator']'
::method string
  expose _numerator _denominator
  if _denominator=1 then return _numerator
  return _numerator'/'_denominator
::method coerce class
  use strict arg value, context=.nil
  if value~isA(.MathRational) then return value
  text=value~string~strip
  if text~pos('(')>0 | text~pos(')')>0 then return .MathRational~fromRepeatingDecimal(text,context)
  slash=text~pos('/')
  if slash>0 then do
    if text~substr(slash+1)~pos('/')>0 then raise syntax 88.900 array('single exact fraction literal',text)
    return .MathRational~of(text~left(slash-1)~strip,text~substr(slash+1)~strip,context)
  end
  return .MathRational~fromDecimal(text,context)
::method fromDecimal class
  use strict arg text, context=.nil
  s=text~string~strip
  if s='' then raise syntax 88.900 array('exact decimal or integer literal',s)
  sign=1
  if s~left(1)='-' then do; sign=-1; s=s~substr(2); end
  else if s~left(1)='+' then s=s~substr(2)
  parse upper var s mant 'E' exponent
  if exponent='' then exponent=0
  if \rx_math_is_signed_integer_text(exponent) then raise syntax 88.900 array('integer decimal exponent',exponent)
  dot=mant~pos('.')
  if dot=0 then do; whole=mant; frac=''; end
  else do; whole=mant~left(dot-1); frac=mant~substr(dot+1); end
  if whole='' then whole='0'
  digits=whole||frac
  if digits='' | \rx_math_is_unsigned_digits(digits) then raise syntax 88.900 array('exact decimal literal',text)
  scale=frac~length-(exponent+0)
  work=digits~length+scale~abs+12
  if work<32 then work=32
  numeric digits work
  if sign<0 then n=('-'||digits)+0; else n=digits+0
  if scale<=0 then return .MathRational~of(n * (10 ** (-scale)),1,context)
  return .MathRational~of(n,10 ** scale,context)
::method fromRepeatingDecimal class
  use strict arg text, context=.nil
  if context == .nil then context=.MathContext~rational
  s=text~string~strip
  if s='' then raise syntax 88.900 array('exact repeating decimal such as 0.(3) or 0.1(6)',s)
  sign=1
  if s~left(1)='-' then do; sign=-1; s=s~substr(2); end
  else if s~left(1)='+' then s=s~substr(2)
  open=s~pos('(')
  if open=0 | s~right(1)<>')' then raise syntax 88.900 array('exact repeating decimal such as 0.(3) or 0.1(6)',text)
  if s~substr(open+1)~pos('(')>0 then raise syntax 88.900 array('single repeating decimal cycle',text)
  prefix=s~left(open-1)
  repeat=s~substr(open+1,s~length-open-1)
  if repeat='' | \rx_math_is_unsigned_digits(repeat) then raise syntax 88.900 array('non-empty repeating digit cycle',text)
  dot=prefix~pos('.')
  if dot=0 | prefix~substr(dot+1)~pos('.')>0 then raise syntax 88.900 array('decimal point before repeating cycle',text)
  whole=prefix~left(dot-1); nonrep=prefix~substr(dot+1)
  if whole='' | \rx_math_is_unsigned_digits(whole) then raise syntax 88.900 array('integer part in repeating decimal',text)
  if nonrep<>'' then if \rx_math_is_unsigned_digits(nonrep) then raise syntax 88.900 array('non-repeating decimal digits',text)
  m=nonrep~length; n=repeat~length
  work=whole~length+nonrep~length+repeat~length+m+n+24
  if work<50 then work=50
  numeric digits work
  if nonrep='' then a=0; else a=nonrep+0
  b=repeat+0
  base=10**m
  cycle=(10**n)-1
  den=base*cycle
  num=(whole+0)*den + a*cycle + b
  if sign<0 then num=0-num
  out=.MathRational~of(num,den,context)
  ev=.MathEvidence~new('rational.parseRepeatingDecimal',context,.array~of(text~string))
  ev~addStep(.MathPathStep~new('rational.parseRepeatingDecimal','PURE','0.7','exact-geometric-series-decimal-conversion','EXACT_RATIONAL','exact','repeating decimal converted algebraically to rational','no floating-point conversion; denominator=10^m*(10^n-1)','EXACT','PURE,RATIONAL,REPEATING-DECIMAL'))
  ev~putCheck('source',text~string)
  ev~putCheck('canonical',out~string)
  out~_setEvidence(ev)
  return out

::method decimalExpansion
  expose _numerator _denominator
  use strict arg maxDigits=10000
  if \datatype(maxDigits,'W') | maxDigits<1 then raise syntax 88.900 array('positive maximum decimal-expansion digits',maxDigits)
  work=rx_math_integer_work_digits(_numerator,_denominator)+16
  if work<50 then work=50
  numeric digits work
  n=_numerator; sign=1
  if n<0 then do; sign=-1; n=0-n; end
  integerPart=n%_denominator
  remainder=n//_denominator
  digits=''; nonrep=''; repeat=''
  positions=.directory~new
  pos=1
  do while remainder<>0
    key=remainder~string
    if positions~hasIndex(key) then do
      cycleStart=positions[key]
      nonrep=digits~left(cycleStart-1)
      repeat=digits~substr(cycleStart)
      leave
    end
    if pos>maxDigits then raise syntax 88.900 array('decimal expansion period within maxDigits='maxDigits,self~string)
    positions[key]=pos
    remainder=remainder*10
    digit=remainder%_denominator
    remainder=remainder//_denominator
    digits=digits||digit
    pos+=1
  end
  if remainder=0 then nonrep=digits
  ev=.MathEvidence~new('rational.decimalExpansion',self~context,.array~of(self~canonical))
  ev~addStep(.MathPathStep~new('rational.decimalExpansion','PURE','0.7','exact-long-division-cycle-detection','BASE10_EXACT_EXPANSION','exact','finite or recurring base-10 expansion derived by exact integer long division','remainders are retained exactly; recurring cycle begins when a remainder repeats','EXACT','PURE,RATIONAL,LONG-DIVISION,CYCLE-DETECTION'))
  ev~putCheck('source',self~string)
  ev~putCheck('terminating',(repeat=''))
  ev~putCheck('periodLength',repeat~length)
  return .MathDecimalExpansion~new(sign,integerPart,nonrep,repeat,self,self~context,ev)

::method _result
  use strict arg operation,numerator,denominator,operands,parameter=.nil
  inputs=.array~new
  do item over operands; inputs~append(item~canonical); end
  pair=rx_math_normalize_fraction(numerator,denominator)
  unred=numerator~string'/'denominator~string
  if pair[2]=1 then canonical=pair[1]~string
  else canonical=pair[1]~string'/'pair[2]~string
  ev=.MathEvidence~new(operation,self~context,inputs)
  ev~addStep(.MathPathStep~new(operation,'PURE','0.7','exact-integer-rational-arithmetic','EXACT_RATIONAL','exact','normalized numerator/denominator','unreduced='unred'; canonical='canonical'; integer arithmetic followed by exact gcd normalization','EXACT','PURE,RATIONAL,INTEGER-GCD'))
  ev~putCheck('exact','1')
  ev~putCheck('unreduced',unred)
  ev~putCheck('canonical',canonical)
  deriv=.MathDerivation~new(operation,operands,parameter)
  return .MathRational~of(pair[1],pair[2],self~context,ev,deriv)
::method '+'
  expose _numerator _denominator
  use strict arg other=.nil
  if arg(1,'O') then return self
  r=.MathRational~coerce(other,self~context)
  work=rx_math_rational_binary_digits(self,r)+8
  numeric digits work
  /* Use the least common denominator rather than blindly multiplying the
   * denominators.  Besides limiting integer growth, this keeps the retained
   * mathematical path natural: 2/3 + 1/3 reaches 3/3 before canonicalizing. */
  g=rx_math_integer_gcd(_denominator,r~denominator,work)
  lscale=_denominator/g; rscale=r~denominator/g
  n=(_numerator*rscale)+(r~numerator*lscale)
  d=lscale*r~denominator
  return self~_result('rational.add',n,d,.array~of(self,r))
::method '-'
  expose _numerator _denominator
  use strict arg other=.nil
  if arg(1,'O') then return self~_result('rational.neg',-_numerator,_denominator,.array~of(self))
  r=.MathRational~coerce(other,self~context)
  work=rx_math_rational_binary_digits(self,r)+8
  numeric digits work
  g=rx_math_integer_gcd(_denominator,r~denominator,work)
  lscale=_denominator/g; rscale=r~denominator/g
  n=(_numerator*rscale)-(r~numerator*lscale)
  d=lscale*r~denominator
  return self~_result('rational.sub',n,d,.array~of(self,r))
::method '*'
  expose _numerator _denominator
  use strict arg other
  r=.MathRational~coerce(other,self~context)
  work=rx_math_rational_binary_digits(self,r)+8
  numeric digits work
  return self~_result('rational.mul',_numerator*r~numerator,_denominator*r~denominator,.array~of(self,r))
::method '/'
  expose _numerator _denominator
  use strict arg other
  r=.MathRational~coerce(other,self~context)
  if r~numerator=0 then raise syntax 42.3
  work=rx_math_rational_binary_digits(self,r)+8
  numeric digits work
  return self~_result('rational.div',_numerator*r~denominator,_denominator*r~numerator,.array~of(self,r))
::method '**'
  expose _numerator _denominator
  use strict arg exponent
  if \datatype(exponent,'W') then raise syntax 88.900 array('whole-number exponent',exponent)
  if exponent=0 then return .MathRational~of(1,1,self~context)
  n=exponent~abs
  work=(rx_math_integer_text_digits(_numerator)+rx_math_integer_text_digits(_denominator))*n+8
  numeric digits work
  if exponent>0 then return self~_result('rational.pow',_numerator**n,_denominator**n,.array~of(self),exponent)
  if _numerator=0 then raise syntax 42.3
  return self~_result('rational.pow',_denominator**n,_numerator**n,.array~of(self),exponent)
::method abs
  expose _numerator _denominator
  work=rx_math_integer_work_digits(_numerator,_denominator)+8
  numeric digits work
  if _numerator<0 then return .MathRational~of(0-_numerator,_denominator,self~context)
  return self
::method compareTo
  expose _numerator _denominator
  use strict arg other
  r=.MathRational~coerce(other,self~context)
  work=rx_math_rational_binary_digits(self,r)+8
  numeric digits work
  delta=(_numerator*r~denominator)-(r~numerator*_denominator)
  return delta~sign
::method '='
  use strict arg other
  if \rx_math_can_coerce_rational(other) then return .false
  return self~compareTo(other)=0
::method '\='
  use strict arg other
  if \rx_math_can_coerce_rational(other) then return .true
  return self~compareTo(other)<>0
::method '<'
  use strict arg other
  return self~compareTo(other)<0
::method '>'
  use strict arg other
  return self~compareTo(other)>0
::method '<='
  use strict arg other
  return self~compareTo(other)<=0
::method '>='
  use strict arg other
  return self~compareTo(other)>=0
::method toDecimal
  expose _numerator _denominator
  use strict arg digits=.nil
  if digits == .nil then digits=self~context~requestedDigits
  if \datatype(digits,'W') | digits<1 then raise syntax 88.900 array('positive decimal digits',digits)
  numeric digits digits+self~context~guardDigits
  return _numerator/_denominator
::method format
  expose _numerator _denominator
  use strict arg style='FRACTION', digits=.nil
  style=style~upper
  select
    when style='FRACTION' | style='EXACT' then return self~string
    when style='DECIMAL' then do
      if digits == .nil then digits=self~context~requestedDigits
      if \datatype(digits,'W') | digits<1 then raise syntax 88.900 array('positive decimal digits',digits)
      numeric digits digits+self~context~guardDigits
      return _numerator/_denominator
    end
    when style='EXPANSION' | style='REPEATING' then do
      if digits == .nil then digits=10000
      return self~decimalExpansion(digits)~string
    end
    when style='MIXED' then do
      if _denominator=1 then return _numerator
      work=rx_math_integer_work_digits(_numerator,_denominator)+8
      numeric digits work
      whole=_numerator % _denominator
      rem=(_numerator // _denominator)~abs
      if whole=0 then return _numerator'/'_denominator
      if rem=0 then return whole
      return whole' 'rem'/'_denominator
    end
    otherwise raise syntax 88.900 array('FRACTION, EXACT, DECIMAL, EXPANSION, REPEATING, or MIXED format',style)
  end
::method prove
  use strict arg claim=.nil, assumptions=.nil, policy=.nil
  if claim == .nil then claim=.MathClaim~isExact
  return .MathProofPlanner~prove(self,claim,assumptions,policy)


::class MathFraction subclass MathRational public
::method init
  use strict arg numerator, denominator, context=.nil, evidence=.nil, derivation=.nil
  if context == .nil then context=.MathContext~rational
  self~init:super(numerator,denominator,context,evidence,derivation)
  if self~denominator=1 then raise syntax 88.900 array('proper fraction with denominator greater than one after normalization',self~string)
::method isFraction; return .true
::method isInteger; return .false


::class MathInteger subclass MathRational public
::method init
  use strict arg value=0, context=.nil, evidence=.nil, derivation=.nil
  if context == .nil then context=.MathContext~rational
  self~init:super(value,1,context,evidence,derivation)
::method isInteger; return .true
::method isFraction; return .false
::method canonical
  return 'integer['self~numerator']'
::method string
  return self~numerator
::method format
  use strict arg style='INTEGER', digits=.nil
  style=style~upper
  select
    when style='INTEGER' | style='FRACTION' | style='EXACT' | style='MIXED' | style='EXPANSION' | style='REPEATING' then return self~string
    when style='DECIMAL' then return self~string
    otherwise raise syntax 88.900 array('INTEGER, FRACTION, EXACT, DECIMAL, EXPANSION, REPEATING, or MIXED format',style)
  end


::class MathDecimalExpansion subclass MathValue public
::method init
  expose _sign _integerPart _nonRepeating _repeating _source
  use strict arg sign, integerPart, nonRepeating, repeating, source, context, evidence=.nil
  self~init:super(context,evidence,.nil)
  _sign=sign; _integerPart=integerPart; _nonRepeating=nonRepeating; _repeating=repeating; _source=source
::method sign; expose _sign; return _sign
::method integerPart; expose _integerPart; return _integerPart
::method nonRepeatingDigits; expose _nonRepeating; return _nonRepeating
::method repeatingDigits; expose _repeating; return _repeating
::method periodLength; expose _repeating; return _repeating~length
::method isTerminating; expose _repeating; return _repeating=''
::method isRecurring; expose _repeating; return _repeating<>''
::method isExact; return .true
::method source; expose _source; return _source
::method toRational; expose _source; return _source
::method canonical
  return 'decimal-expansion['self~string']'
::method string
  expose _sign _integerPart _nonRepeating _repeating
  prefix=''; if _sign<0 then prefix='-'
  if _repeating='' then do
    if _nonRepeating='' then return prefix||_integerPart
    return prefix||_integerPart'.'_nonRepeating
  end
  return prefix||_integerPart'.'_nonRepeating'('_repeating')'
::method prove
  expose _source _repeating
  use strict arg claim=.nil, assumptions=.nil, policy=.nil
  if claim == .nil then claim=.MathClaim~isExact
  if claim~kind<>'IS_EXACT' then return _source~prove(claim,assumptions,policy)
  if _repeating='' then replay=.MathRational~fromDecimal(self~string,self~context)
  else replay=.MathRational~fromRepeatingDecimal(self~string,self~context)
  checks=.directory~new
  checks['expansion']=self~string
  checks['sourceRational']=_source~string
  checks['replayedRational']=replay~string
  if replay=_source then do
    checks['exactRoundTrip']='1'
    return .MathProof~new('EXACT',self~evidence,replay~evidence,checks,.array~of('Exact expansion independently replayed back to the same canonical rational.'),claim,assumptions,'PROVED')
  end
  checks['exactRoundTrip']='0'
  return .MathProof~new('DISAGREEMENT',self~evidence,replay~evidence,checks,.array~of('Expansion replay did not recover the source rational.'),claim,assumptions,'DISPROVED')

::class MathBall subclass MathValue public
::method init
  expose _enclosure _relativeAccuracyBits _isExact _provider
  use strict arg enclosure, relativeAccuracyBits, isExact, provider, context, evidence
  self~init:super(context,evidence,.nil)
  _enclosure=enclosure; _relativeAccuracyBits=relativeAccuracyBits; _isExact=isExact; _provider=provider~upper
::method enclosure; expose _enclosure; return _enclosure
::method relativeAccuracyBits; expose _relativeAccuracyBits; return _relativeAccuracyBits
::method isExact; expose _isExact; return _isExact
::method provider; expose _provider; return _provider
::method string; expose _enclosure; return _enclosure
::method prove
  use strict arg claim=.nil, assumptions=.nil, policy=.nil
  if claim == .nil then claim=.MathClaim~enclosesExactEvaluation
  return .MathProofPlanner~prove(self,claim,assumptions,policy)


::class MathExpression public
::method init
  expose _context
  use strict arg context=.nil
  if context == .nil then context=.Maths~defaultContext
  _context=context
::method context; expose _context; return _context
::method coerce class
  use strict arg value, context=.nil
  if value~isA(.MathExpression) then return value
  return .MathConstant~new(value,context)
::method '+'
  use strict arg other
  return .MathBinaryExpression~new('ADD',self,self~class~coerce(other,self~context),self~context)
::method '-'
  use strict arg other=.nil
  if arg(1,'O') then return .MathBinaryExpression~new('MUL',.MathConstant~new(-1,self~context),self,self~context)
  return .MathBinaryExpression~new('SUB',self,self~class~coerce(other,self~context),self~context)
::method '*'
  use strict arg other
  return .MathBinaryExpression~new('MUL',self,self~class~coerce(other,self~context),self~context)
::method '/'
  use strict arg other
  return .MathBinaryExpression~new('DIV',self,self~class~coerce(other,self~context),self~context)
::method '**'
  use strict arg other
  return .MathBinaryExpression~new('POW',self,self~class~coerce(other,self~context),self~context)
::method simplify; return self
::method prove
  use strict arg claim=.nil, assumptions=.nil, policy=.nil
  if claim == .nil then claim=.MathClaim~equals(0)
  return .MathProofPlanner~prove(self,claim,assumptions,policy)
::method interval
  use strict arg bounds, context=.nil
  if context == .nil then context=self~context
  p=.Maths~provider('MPMATH-IV')
  if p == .nil then raise syntax 88.900 array('registered MPMATH-IV maths provider','not loaded')
  return p~intervalEvaluate(self,bounds,context)
::method ball
  use strict arg bounds, context=.nil
  if context == .nil then context=self~context
  p=.Maths~provider('FLINT-ARB')
  if p == .nil then raise syntax 88.900 array('registered FLINT-ARB maths provider','python-flint/Arb is not available')
  return p~ballEvaluate(self,bounds,context)


::class MathConstant subclass MathExpression public
::method init
  expose _text _exact
  use strict arg value, context=.nil, exact=.nil
  self~init:super(context)
  _text=value~string
  if exact == .nil then _exact=datatype(_text,'W'); else _exact=exact
::method text; expose _text; return _text
::method exact; expose _exact; return _exact
::method isExactZero; expose _text _exact; return _exact & _text=0
::method isExactOne; expose _text _exact; return _exact & _text=1
::method canonical; expose _text _exact; return 'const('_text';exact='_exact')'
::method providerText; expose _text; return _text
::method evaluate; expose _text; return _text+0
::method string; expose _text; return _text


::class MathVariable subclass MathExpression public
::method init
  expose _name
  use strict arg name, context=.nil
  self~init:super(context)
  if \rx_math_valid_symbol_name(name) then raise syntax 88.900 array('simple mathematical variable name',name)
  _name=name
::method name; expose _name; return _name
::method canonical; expose _name; return 'var('_name')'
::method providerText; expose _name; return _name
::method evaluate
  expose _name
  use strict arg values
  if \values~hasIndex(_name) then raise syntax 88.900 array('assignment for variable '_name,'missing')
  return values[_name]
::method string; expose _name; return _name


::class MathBinaryExpression subclass MathExpression public
::method init
  expose _op _left _right
  use strict arg op,left,right,context=.nil
  self~init:super(context); _op=op~upper; _left=left; _right=right
::method op; expose _op; return _op
::method left; expose _left; return _left
::method right; expose _right; return _right
::method canonical
  expose _op _left _right
  return _op'('_left~canonical','_right~canonical')'
::method providerText
  expose _op _left _right
  select
    when _op='ADD' then sym='+'
    when _op='SUB' then sym='-'
    when _op='MUL' then sym='*'
    when _op='DIV' then sym='/'
    when _op='POW' then sym='**'
    otherwise raise syntax 88.900 array('known expression operator',_op)
  end
  return '('_left~providerText sym _right~providerText')'
::method evaluate
  expose _op _left _right
  use strict arg values
  numeric digits self~context~workingDigits
  l=_left~evaluate(values); r=_right~evaluate(values)
  select
    when _op='ADD' then return l+r
    when _op='SUB' then return l-r
    when _op='MUL' then return l*r
    when _op='DIV' then return l/r
    when _op='POW' then return l**r
  end
::method simplify
  expose _op _left _right
  l=_left~simplify; r=_right~simplify
  /* Structural identities below are deliberately small and sound. Serious CAS work belongs to SymPy. */
  if _op='SUB' & l~canonical=r~canonical then return .MathConstant~new(0,self~context,.true)
  if _op='ADD' then do
    if l~isA(.MathConstant) then if l~isExactZero then return r
    if r~isA(.MathConstant) then if r~isExactZero then return l
  end
  if _op='SUB' then if r~isA(.MathConstant) then if r~isExactZero then return l
  if _op='MUL' then do
    if l~isA(.MathConstant) then do
      if l~isExactZero then return .MathConstant~new(0,self~context,.true)
      if l~isExactOne then return r
    end
    if r~isA(.MathConstant) then do
      if r~isExactZero then return .MathConstant~new(0,self~context,.true)
      if r~isExactOne then return l
    end
  end
  return .MathBinaryExpression~new(_op,l,r,self~context)
::method string; return self~providerText


::class MathInterval subclass MathValue public
::method init
  expose _lower _upper _width _enclosure
  use strict arg lower,upper,width,enclosure,context,evidence
  self~init:super(context,evidence,.nil)
  _lower=lower; _upper=upper; _width=width; _enclosure=enclosure
::method lower; expose _lower; return _lower
::method upper; expose _upper; return _upper
::method width; expose _width; return _width
::method enclosure; expose _enclosure; return _enclosure
::method string; expose _enclosure; return _enclosure
::method prove
  use strict arg claim=.nil, assumptions=.nil, policy=.nil
  if claim == .nil then claim=.MathClaim~enclosesExactEvaluation
  return .MathProofPlanner~prove(self,claim,assumptions,policy)


::class MathComplex subclass MathValue public
::method init
  expose _real _imaginary
  use strict arg real=0, imaginary=0, context=.nil, evidence=.nil, derivation=.nil
  if context == .nil then context=.Maths~defaultContext
  self~init:super(context,evidence,derivation)
  numeric digits context~workingDigits
  _real=real+0; _imaginary=imaginary+0
::method real; expose _real; return _real
::method imaginary; expose _imaginary; return _imaginary
::method '+'
  expose _real _imaginary
  use strict arg other=.nil
  if arg(1,'O') then return self
  if \other~isA(.MathComplex) then other=.MathComplex~new(other,0,self~context)
  numeric digits self~context~workingDigits
  return .MathComplex~new(_real+other~real,_imaginary+other~imaginary,self~context)
::method '-'
  expose _real _imaginary
  use strict arg other=.nil
  if arg(1,'O') then return .MathComplex~new(-_real,-_imaginary,self~context)
  if \other~isA(.MathComplex) then other=.MathComplex~new(other,0,self~context)
  numeric digits self~context~workingDigits
  return .MathComplex~new(_real-other~real,_imaginary-other~imaginary,self~context)
::method '*'
  expose _real _imaginary
  use strict arg other
  if \other~isA(.MathComplex) then other=.MathComplex~new(other,0,self~context)
  numeric digits self~context~workingDigits
  return .MathComplex~new((_real*other~real)-(_imaginary*other~imaginary),(_real*other~imaginary)+(_imaginary*other~real),self~context)
::method '/'
  expose _real _imaginary
  use strict arg other
  if \other~isA(.MathComplex) then other=.MathComplex~new(other,0,self~context)
  numeric digits self~context~workingDigits
  d=other~real**2+other~imaginary**2
  if d=0 then raise syntax 42.3
  return .MathComplex~new(((_real*other~real)+(_imaginary*other~imaginary))/d,((_imaginary*other~real)-(_real*other~imaginary))/d,self~context)
::method '**'
  use strict arg exponent
  if \datatype(exponent,'W') then raise syntax 88.900 array('whole-number exponent',exponent)
  one=.MathComplex~new(1,0,self~context)
  if exponent=0 then return one
  n=exponent~abs; p=self; out=one
  do while n>0
    if n//2=1 then out=out*p
    p=p*p; n=n%2
  end
  if exponent<0 then return one/out
  return out
::method conjugate
  expose _real _imaginary
  return .MathComplex~new(_real,-_imaginary,self~context)
::method string
  expose _real _imaginary
  if _imaginary=0 then return _real
  if _real=0 then return _imaginary'i'
  if _imaginary>0 then return _real'+'_imaginary'i'
  return _real||_imaginary'i'


::class MathVector subclass MathValue public
::method init
  expose _data
  use strict arg data, context=.nil, evidence=.nil, derivation=.nil
  if context == .nil then context=.Maths~defaultContext
  self~init:super(context,evidence,derivation)
  if \data~isA(.array) then raise syntax 88.900 array('Array',data~class~id)
  _data=.array~new
  numeric digits context~workingDigits
  do v over data; _data~append(rx_math_coerce_value(v,context)); end
::method size; expose _data; return _data~items
::method items; expose _data; return _data~items
::method at; expose _data; use strict arg i; return _data[i]
::method '[]'; expose _data; use strict arg i; return _data[i]
::method toArray
  expose _data
  out=.array~new; do v over _data; out~append(v); end; return out
::method canonical
  expose _data
  s='vector['; first=.true
  do v over _data
    if \first then s=s','; first=.false; s=s||v
  end
  return s']'
::method '+'
  use strict arg other
  return .Maths~providerFor(self~context,'vector.add')~vectorAdd(self,other,self~context)
::method '-'
  use strict arg other=.nil
  if arg(1,'O') then return self * -1
  return .Maths~providerFor(self~context,'vector.sub')~vectorSub(self,other,self~context)
::method '*'
  use strict arg other
  return .Maths~providerFor(self~context,'vector.mul')~vectorMul(self,other,self~context)
::method hadamard
  use strict arg other
  return .Maths~providerFor(self~context,'vector.hadamard')~vectorHadamard(self,other,self~context)
::method quantize
  use strict arg scheme=.nil
  if scheme == .nil then scheme=.MathQuantizationScheme~int8
  return .MathQuantizer~quantize(self,scheme)
::method string
  expose _data
  s='['; first=.true
  do v over _data; if \first then s=s', '; first=.false; s=s||v; end
  return s']'


::class MathMatrix subclass MathValue public
::method init
  expose _data _rows _cols _backendProvider _backendValue
  use strict arg data, context=.nil, evidence=.nil, derivation=.nil, backendProvider='', backendValue=.nil
  if context == .nil then context=.Maths~defaultContext
  self~init:super(context,evidence,derivation)
  if \data~isA(.array) then raise syntax 88.900 array('Array of rows',data~class~id)
  _data=.array~new; _rows=data~items; _cols=0
  numeric digits context~workingDigits
  r=0
  do row over data
    r+=1
    if \row~isA(.array) then raise syntax 88.900 array('Array row',row~class~id)
    if r=1 then _cols=row~items
    else if row~items<>_cols then raise syntax 88.900 array('rectangular matrix','row 'r)
    copy=.array~new; do v over row; copy~append(rx_math_coerce_value(v,context)); end
    _data~append(copy)
  end
  if _rows=0 then _cols=0
  _backendProvider=backendProvider~upper; _backendValue=backendValue
  if evidence == .nil then do
    ev=.MathEvidence~new('matrix.construct',context,.array~of(self~canonical))
    ev~addStep(.MathPathStep~new('matrix.construct','PURE','0.7','canonical-copy',context~numberDomain,context~workingDigits,rx_math_representation(context),'rectangular validation'))
    self~_setEvidence(ev)
  end
::method rows; expose _rows; return _rows
::method cols; expose _cols; return _cols
::method isSquare; expose _rows _cols; return _rows=_cols
::method at; expose _data; use strict arg row,col; return _data[row][col]
::method '[]'; expose _data; use strict arg row,col; return _data[row][col]
::method toArray
  expose _data
  out=.array~new
  do row over _data
    copy=.array~new; do v over row; copy~append(v); end
    out~append(copy)
  end
  return out
::method backendProvider; expose _backendProvider; return _backendProvider
::method backendValue; expose _backendValue; return _backendValue
::method _attachBackend
  expose _backendProvider _backendValue
  use strict arg provider,value
  _backendProvider=provider~upper; _backendValue=value; return self
::method canonical
  expose _data _rows _cols
  s='matrix['_rows'x'_cols']:'
  rfirst=.true
  do row over _data
    if \rfirst then s=s';'; rfirst=.false
    cfirst=.true
    do v over row
      if \cfirst then s=s','; cfirst=.false; s=s||v
    end
  end
  return s
::method '+'
  use strict arg other
  return .Maths~providerFor(self~context,'matrix.add')~matrixAdd(self,other,self~context)
::method '-'
  use strict arg other=.nil
  if arg(1,'O') then return self * -1
  return .Maths~providerFor(self~context,'matrix.sub')~matrixSub(self,other,self~context)
::method '*'
  use strict arg other
  return .Maths~providerFor(self~context,'matrix.mul')~matrixMul(self,other,self~context)
::method transpose
  return .Maths~providerFor(self~context,'matrix.transpose')~matrixTranspose(self,self~context)
::method solve
  use strict arg b
  if \b~isA(.MathVector) & \b~isA(.MathMatrix) then b=.MathVector~new(b,self~context)
  return .Maths~providerFor(self~context,'matrix.solve')~matrixSolve(self,b,self~context)
::method inverse
  expose _rows _cols
  if _rows<>_cols then raise syntax 88.900 array('square matrix',self~canonical)
  return self~solve(.MathMatrix~identity(_rows,self~context))
::method identity class
  use strict arg n, context=.nil
  if context == .nil then context=.Maths~defaultContext
  if \datatype(n,'W') | n<1 then raise syntax 88.900 array('positive matrix size',n)
  rows=.array~new
  do i=1 to n
    row=.array~new
    do j=1 to n; if i=j then row~append(1); else row~append(0); end
    rows~append(row)
  end
  return self~new(rows,context)
::method quantize
  use strict arg scheme=.nil
  if scheme == .nil then scheme=.MathQuantizationScheme~int8
  return .MathQuantizer~quantize(self,scheme)
::method maxAbsDifference
  use strict arg other
  if self~rows<>other~rows | self~cols<>other~cols then return 'INF'
  numeric digits max(self~context~workingDigits,other~context~workingDigits)
  m=rx_math_zero(self~context)
  do i=1 to self~rows
    do j=1 to self~cols
      d=(self[i,j]-other[i,j])~abs
      if rx_math_compare(d,m,self~context)>0 then m=d
    end
  end
  return m
::method string
  expose _data
  nl='0a'x; s=''
  do row over _data
    if s<>'' then s=s||nl
    line='['; first=.true
    do v over row; if \first then line=line' '; first=.false; line=line||v; end
    s=s||line']'
  end
  return s
::method uninit
  expose _backendValue
  if symbol('_backendValue')='VAR' then if _backendValue \== .nil then do
    if _backendValue~hasMethod('CLOSE') then _backendValue~close
  end


::class MathProvider public
::method name abstract
::method version; return '0.7'
::method supports
  use strict arg operation
  return .false

::class MathPureProvider subclass MathProvider public
::method name; return 'PURE'
::method supports
  use strict arg operation
  return operation~word(1)<>''
::method _step
  use strict arg operation,context,algorithm,details=''
  do
    if context~numberDomain='RATIONAL' then do; guarantee='EXACT'; wd='dynamic-integer'; end; else do; guarantee='APPROXIMATE'; wd=context~workingDigits; end
    return .MathPathStep~new(operation,self~name,self~version,algorithm,context~numberDomain,wd,rx_math_representation(context),details,guarantee,'PURE,'context~numberDomain','algorithm)
  end
::method _matrixEvidence
  use strict arg operation,context,inputs,algorithm,details=''
  ev=.MathEvidence~new(operation,context,inputs); ev~addStep(self~_step(operation,context,algorithm,details)); return ev
::method vectorAdd
  use strict arg left,right,context
  if left~size<>right~size then raise syntax 88.900 array('equal vector dimensions',left~size'/'right~size)
  numeric digits context~workingDigits; out=.array~new
  do i=1 to left~size; out~append(left[i]+right[i]); end
  ev=self~_matrixEvidence('vector.add',context,.array~of(left~canonical,right~canonical),'elementwise-add')
  return .MathVector~new(out,context,ev,.MathDerivation~new('vector.add',.array~of(left,right)))
::method vectorSub
  use strict arg left,right,context
  if left~size<>right~size then raise syntax 88.900 array('equal vector dimensions',left~size'/'right~size)
  numeric digits context~workingDigits; out=.array~new
  do i=1 to left~size; out~append(left[i]-right[i]); end
  ev=self~_matrixEvidence('vector.sub',context,.array~of(left~canonical,right~canonical),'elementwise-subtract')
  return .MathVector~new(out,context,ev,.MathDerivation~new('vector.sub',.array~of(left,right)))
::method vectorMul
  use strict arg left,right,context
  numeric digits context~workingDigits
  if right~isA(.MathVector) then do
    if left~size<>right~size then raise syntax 88.900 array('equal vector dimensions',left~size'/'right~size)
    s=rx_math_zero(context); do i=1 to left~size; s=s+left[i]*right[i]; end
    ev=self~_matrixEvidence('vector.dot',context,.array~of(left~canonical,right~canonical),'dot-product')
    if s~isA(.MathRational) then do; s~_setEvidence(ev); s~_setDerivation(.MathDerivation~new('vector.dot',.array~of(left,right))); end
    return s
  end
  right=rx_math_scalar_for_context(right,context,'numeric scalar or MathVector')
  out=.array~new; do i=1 to left~size; out~append(left[i]*right); end
  ev=self~_matrixEvidence('vector.scale',context,.array~of(left~canonical,right),'scalar-multiply')
  return .MathVector~new(out,context,ev,.MathDerivation~new('vector.scale',.array~of(left),right))
::method vectorHadamard
  use strict arg left,right,context
  if left~size<>right~size then raise syntax 88.900 array('equal vector dimensions',left~size'/'right~size)
  numeric digits context~workingDigits; out=.array~new
  do i=1 to left~size; out~append(left[i]*right[i]); end
  ev=self~_matrixEvidence('vector.hadamard',context,.array~of(left~canonical,right~canonical),'elementwise-multiply')
  return .MathVector~new(out,context,ev,.MathDerivation~new('vector.hadamard',.array~of(left,right)))
::method matrixAdd
  use strict arg left,right,context
  call rx_math_check_same_shape left,right
  numeric digits context~workingDigits; rows=.array~new
  do i=1 to left~rows
    row=.array~new; do j=1 to left~cols; row~append(left[i,j]+right[i,j]); end; rows~append(row)
  end
  ev=self~_matrixEvidence('matrix.add',context,.array~of(left~canonical,right~canonical),'elementwise-add')
  return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.add',.array~of(left,right)))
::method matrixSub
  use strict arg left,right,context
  call rx_math_check_same_shape left,right
  numeric digits context~workingDigits; rows=.array~new
  do i=1 to left~rows
    row=.array~new; do j=1 to left~cols; row~append(left[i,j]-right[i,j]); end; rows~append(row)
  end
  ev=self~_matrixEvidence('matrix.sub',context,.array~of(left~canonical,right~canonical),'elementwise-subtract')
  return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.sub',.array~of(left,right)))
::method matrixMul
  use strict arg left,right,context
  numeric digits context~workingDigits
  if right~isA(.MathMatrix) then do
    if left~cols<>right~rows then raise syntax 88.900 array('compatible matrix dimensions',left~rows'x'left~cols' * 'right~rows'x'right~cols)
    rows=.array~new
    do i=1 to left~rows
      row=.array~new
      do j=1 to right~cols
        s=rx_math_zero(context)
        do k=1 to left~cols; s=s+left[i,k]*right[k,j]; end
        row~append(s)
      end
      rows~append(row)
    end
    ev=self~_matrixEvidence('matrix.matmul',context,.array~of(left~canonical,right~canonical),'ijk-dot-product')
    return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.matmul',.array~of(left,right)))
  end
  if right~isA(.MathVector) then do
    if left~cols<>right~size then raise syntax 88.900 array('compatible matrix/vector dimensions',left~cols'/'right~size)
    out=.array~new
    do i=1 to left~rows
      s=rx_math_zero(context); do k=1 to left~cols; s=s+left[i,k]*right[k]; end; out~append(s)
    end
    ev=self~_matrixEvidence('matrix.matvec',context,.array~of(left~canonical,right~canonical),'row-dot-vector')
    return .MathVector~new(out,context,ev,.MathDerivation~new('matrix.matvec',.array~of(left,right)))
  end
  right=rx_math_scalar_for_context(right,context,'numeric scalar, MathVector or MathMatrix')
  rows=.array~new
  do i=1 to left~rows
    row=.array~new; do j=1 to left~cols; row~append(left[i,j]*right); end; rows~append(row)
  end
  ev=self~_matrixEvidence('matrix.scale',context,.array~of(left~canonical,right),'scalar-multiply')
  return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.scale',.array~of(left),right))
::method matrixTranspose
  use strict arg a,context
  rows=.array~new
  do j=1 to a~cols
    row=.array~new; do i=1 to a~rows; row~append(a[i,j]); end; rows~append(row)
  end
  ev=self~_matrixEvidence('matrix.transpose',context,.array~of(a~canonical),'transpose-copy')
  return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.transpose',.array~of(a)))
::method matrixSolve
  use strict arg a,b,context
  if \a~isSquare then raise syntax 88.900 array('square coefficient matrix',a~canonical)
  if b~isA(.MathMatrix) then return self~_solveMatrixRhs(a,b,context)
  if a~rows<>b~size then raise syntax 88.900 array('right-hand vector matching matrix rows',b~size)
  numeric digits context~workingDigits
  n=a~rows; m=.array~new; rhs=.array~new
  do i=1 to n
    row=.array~new; do j=1 to n; row~append(a[i,j]); end; m~append(row); rhs~append(b[i])
  end
  do k=1 to n-1
    pivotRow=k; pivotAbs=m[k][k]~abs
    do i=k+1 to n
      q=m[i][k]~abs; if rx_math_compare(q,pivotAbs,context)>0 then do; pivotAbs=q; pivotRow=i; end
    end
    if rx_math_is_zero(pivotAbs,context) then raise syntax 88.900 array('non-singular matrix','zero pivot at column 'k)
    if pivotRow<>k then do
      temp=m[k]; m[k]=m[pivotRow]; m[pivotRow]=temp
      temp=rhs[k]; rhs[k]=rhs[pivotRow]; rhs[pivotRow]=temp
    end
    do i=k+1 to n
      factor=m[i][k]/m[k][k]
      m[i][k]=rx_math_zero(context)
      do j=k+1 to n; m[i][j]=m[i][j]-factor*m[k][j]; end
      rhs[i]=rhs[i]-factor*rhs[k]
    end
  end
  if rx_math_is_zero(m[n][n],context) then raise syntax 88.900 array('non-singular matrix','zero final pivot')
  x=.array~new(n)
  do i=n to 1 by -1
    s=rhs[i]; do j=i+1 to n; s=s-m[i][j]*x[j]; end; x[i]=s/m[i][i]
  end
  ev=self~_matrixEvidence('matrix.solve',context,.array~of(a~canonical,b~canonical),'gaussian-elimination-partial-pivot','forward elimination + back substitution; zero-pivot singularity test')
  outValue=.MathVector~new(x,context,ev,.MathDerivation~new('matrix.solve',.array~of(a,b)))
  residual=rx_math_residual_norm_inf(a,outValue,b,context)
  ev~putCheck('residualInf',residual)
  return outValue
::method _solveMatrixRhs
  use strict arg a,b,context
  if a~rows<>b~rows then raise syntax 88.900 array('right-hand matrix matching coefficient rows',b~rows)
  cols=.array~new
  do j=1 to b~cols
    v=.array~new; do i=1 to b~rows; v~append(b[i,j]); end
    cols~append(self~matrixSolve(a,.MathVector~new(v,context),context))
  end
  rows=.array~new
  do i=1 to a~rows
    row=.array~new; do j=1 to b~cols; row~append(cols[j][i]); end; rows~append(row)
  end
  ev=self~_matrixEvidence('matrix.solve',context,.array~of(a~canonical,b~canonical),'gaussian-elimination-multiple-rhs','one solve per RHS column')
  return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.solve.matrix',.array~of(a,b)))


::class MathReferenceProvider subclass MathProvider public
::method name; return 'REFERENCE'
::method supports; use strict arg operation; return .true
::method _step
  use strict arg operation,context,algorithm,details=''
  do
    if context~numberDomain='RATIONAL' then do; guarantee='EXACT'; wd='dynamic-integer'; end; else do; guarantee='APPROXIMATE'; wd=context~workingDigits; end
    return .MathPathStep~new(operation,self~name,self~version,algorithm,context~numberDomain,wd,rx_math_representation(context),'independent reference arithmetic;'details,guarantee,'REFERENCE,'context~numberDomain','algorithm)
  end
::method matrixAdd
  use strict arg left,right,context
  call rx_math_check_same_shape left,right
  numeric digits context~workingDigits; rows=.array~new
  do i=1 to left~rows
    row=.array~new; do j=1 to left~cols; row~append(right[i,j]+left[i,j]); end; rows~append(row)
  end
  ev=.MathEvidence~new('matrix.add',context,.array~of(left~canonical,right~canonical)); ev~addStep(self~_step('matrix.add',context,'reverse-operand-elementwise-add'))
  return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.add',.array~of(left,right)))
::method matrixSub
  use strict arg left,right,context
  call rx_math_check_same_shape left,right
  numeric digits context~workingDigits; rows=.array~new
  do i=1 to left~rows
    row=.array~new; do j=1 to left~cols; row~append(-(right[i,j]-left[i,j])); end; rows~append(row)
  end
  ev=.MathEvidence~new('matrix.sub',context,.array~of(left~canonical,right~canonical)); ev~addStep(self~_step('matrix.sub',context,'negated-reverse-subtraction'))
  return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.sub',.array~of(left,right)))
::method matrixMul
  use strict arg left,right,context
  if \right~isA(.MathMatrix) then return .Maths~provider('PURE')~matrixMul(left,right,context)
  if left~cols<>right~rows then raise syntax 88.900 array('compatible matrix dimensions',left~cols'/'right~rows)
  numeric digits context~workingDigits; rows=.array~new
  do i=1 to left~rows
    row=.array~new
    do j=1 to right~cols
      products=.array~new
      do k=left~cols to 1 by -1; products~append(left[i,k]*right[k,j]); end
      s=rx_math_zero(context); do q over products; s=s+q; end
      row~append(s)
    end
    rows~append(row)
  end
  ev=.MathEvidence~new('matrix.matmul',context,.array~of(left~canonical,right~canonical)); ev~addStep(self~_step('matrix.matmul',context,'reverse-k-dot-product','independent loop/order reference path'))
  return .MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.matmul',.array~of(left,right)))
::method matrixTranspose
  use strict arg a,context
  return .Maths~provider('PURE')~matrixTranspose(a,context)
::method matrixSolve
  use strict arg a,b,context
  if b~isA(.MathMatrix) then return .Maths~provider('PURE')~matrixSolve(a,b,context)
  if \a~isSquare | a~rows<>b~size then raise syntax 88.900 array('square system with matching RHS',a~canonical)
  numeric digits context~workingDigits
  n=a~rows; aug=.array~new
  do i=1 to n
    row=.array~new
    do j=1 to n; row~append(a[i,j]); end
    row~append(b[i]); aug~append(row)
  end
  do col=1 to n
    pivot=col; best=aug[col][col]~abs
    do i=col+1 to n
      q=aug[i][col]~abs; if rx_math_compare(q,best,context)>0 then do; best=q; pivot=i; end
    end
    if rx_math_is_zero(best,context) then raise syntax 88.900 array('non-singular matrix','zero pivot at column 'col)
    if pivot<>col then do; tmp=aug[col]; aug[col]=aug[pivot]; aug[pivot]=tmp; end
    d=aug[col][col]
    do j=1 to n+1; aug[col][j]=aug[col][j]/d; end
    do i=1 to n
      if i<>col then do
        factor=aug[i][col]
        if \rx_math_is_zero(factor,context) then do j=1 to n+1; aug[i][j]=aug[i][j]-factor*aug[col][j]; end
      end
    end
  end
  x=.array~new; do i=1 to n; x~append(aug[i][n+1]); end
  ev=.MathEvidence~new('matrix.solve',context,.array~of(a~canonical,b~canonical)); ev~addStep(self~_step('matrix.solve',context,'gauss-jordan-partial-pivot','independent reduced-row-echelon verification path'))
  outValue=.MathVector~new(x,context,ev,.MathDerivation~new('matrix.solve',.array~of(a,b)))
  ev~putCheck('residualInf',rx_math_residual_norm_inf(a,outValue,b,context))
  return outValue
::method vectorAdd; use strict arg l,r,c; return .Maths~provider('PURE')~vectorAdd(l,r,c)
::method vectorSub; use strict arg l,r,c; return .Maths~provider('PURE')~vectorSub(l,r,c)
::method vectorMul; use strict arg l,r,c; return .Maths~provider('PURE')~vectorMul(l,r,c)
::method vectorHadamard; use strict arg l,r,c; return .Maths~provider('PURE')~vectorHadamard(l,r,c)


::class MathDirectProof public
::method rational class
  use strict arg value,claim,assumptions
  checks=.directory~new; checks['value']=value~canonical
  notes=.array~new
  if claim~kind='IS_EXACT' then do
    notes~append('Numerator and denominator are normalized integers; no floating-point representation participates in the value.')
    return .MathProof~new('EXACT',value~evidence,.nil,checks,notes,claim,assumptions,'PROVED')
  end
  if claim~kind='EQUALS' then do
    expected=.MathRational~coerce(claim~expected,value~context)
    checks['expected']=expected~canonical
    if value~numerator=expected~numerator & value~denominator=expected~denominator then outcome='PROVED'; else outcome='DISPROVED'
    notes~append('Equality is decided by normalized exact rational representation.')
    if outcome='PROVED' then strength='EXACT'; else strength='DISPROVED'
    return .MathProof~new(strength,value~evidence,.nil,checks,notes,claim,assumptions,outcome)
  end
  notes~append('No exact rational proof obligation handler is registered for claim kind 'claim~kind'.')
  return .MathProof~new('UNVERIFIED',value~evidence,.nil,checks,notes,claim,assumptions,'INDETERMINATE')

::method ball class
  use strict arg value,claim,assumptions
  checks=.directory~new; checks['relativeAccuracyBits']=value~relativeAccuracyBits; checks['isExact']=value~isExact
  notes=.array~new
  if claim~kind='ENCLOSES_EXACT_EVALUATION' then do
    if value~provider='FLINT-ARB' then do
      notes~append('Certified scope: python-flint/Arb ball evaluation. Arb inclusion semantics provide a rigorous enclosure for supported operations, subject to the recorded inputs and provider implementation.')
      notes~append('A rigorous enclosure may still be too wide to establish a stronger accuracy claim.')
      return .MathProof~new('BALL_CERTIFIED',value~evidence,.nil,checks,notes,claim,assumptions,'PROVED')
    end
  end
  if claim~kind='RELATIVE_ACCURACY_BITS' then do
    need=claim~parameter; checks['requiredBits']=need
    if value~isExact then outcome='PROVED'
    else if datatype(value~relativeAccuracyBits,'W') & value~relativeAccuracyBits>=need then outcome='PROVED'
    else outcome='DISPROVED'
    if outcome='PROVED' then strength='BALL_CERTIFIED'; else strength='DISPROVED'
    notes~append('The claim uses the provider-reported relative accuracy of the rigorous ball, not agreement between approximate implementations.')
    return .MathProof~new(strength,value~evidence,.nil,checks,notes,claim,assumptions,outcome)
  end
  notes~append('Unsupported ball proof claim or non-certifying provider.')
  return .MathProof~new('UNVERIFIED',value~evidence,.nil,checks,notes,claim,assumptions,'INDETERMINATE')

::method interval class
  use strict arg value,claim,assumptions
  checks=.directory~new; checks['lower']=value~lower; checks['upper']=value~upper; checks['width']=value~width
  notes=.array~new
  if claim~kind='ENCLOSES_EXACT_EVALUATION' then do
    if value~evidence \== .nil then if value~evidence~primaryProvider='MPMATH-IV' then do
      notes~append('Certified scope: direct mpmath.iv arithmetic evaluation of the recorded expression over the recorded input intervals.')
      notes~append('Containment does not assert that the enclosure is tight; dependency can make a rigorous interval extremely pessimistic.')
      return .MathProof~new('INTERVAL_CERTIFIED',value~evidence,.nil,checks,notes,claim,assumptions,'PROVED')
    end
    notes~append('No provider certification rule is registered for this interval evidence.')
    return .MathProof~new('UNVERIFIED',value~evidence,.nil,checks,notes,claim,assumptions,'INDETERMINATE')
  end
  if claim~kind='CONTAINS' then do
    numeric digits value~context~workingDigits
    v=claim~expected+0
    if v>=value~lower & v<=value~upper then outcome='PROVED'; else outcome='DISPROVED'
    return .MathProof~new('INTERVAL_MEMBERSHIP',value~evidence,.nil,checks,notes,claim,assumptions,outcome)
  end
  notes~append('Unsupported interval claim kind 'claim~kind'.')
  return .MathProof~new('UNVERIFIED',value~evidence,.nil,checks,notes,claim,assumptions,'INDETERMINATE')

::method expressionLocal class
  use strict arg expression,claim,assumptions
  expected=.MathExpression~coerce(claim~expected,expression~context)
  difference=.MathBinaryExpression~new('SUB',expression,expected,expression~context)
  simple=difference~simplify
  ev=.MathEvidence~new('expression.prove',expression~context,.array~of(expression~canonical,expected~canonical))
  ev~addStep(.MathPathStep~new('expression.prove','PURE','0.7','structural-algebraic-rewrite-v1','SYMBOLIC','exact-where-rules-apply','ooRexx expression tree','small sound rewrite set; not a CAS','EXACT_IF_REDUCED_TO_ZERO','PURE,SYMBOLIC,STRUCTURAL'))
  checks=.directory~new; checks['simplifiedDifference']=simple~providerText
  if simple~isA(.MathConstant) then if simple~isExactZero then do
    notes=.array~of('Proof is exact because the structural rewrite reduced the claimed difference identically to exact integer zero.')
    return .MathProof~new('EXACT',ev,.nil,checks,notes,claim,assumptions,'PROVED')
  end
  notes=.array~of('The local structural simplifier could not establish the identity. This is not evidence that the claim is false.')
  return .MathProof~new('UNVERIFIED',ev,.nil,checks,notes,claim,assumptions,'INDETERMINATE')

::method expressionSympy class
  use strict arg expression,claim,assumptions
  p=.Maths~provider('SYMPY')
  if p == .nil then do
    ev=.MathEvidence~new('expression.prove',expression~context,.array~of(expression~canonical))
    return .MathProof~new('UNVERIFIED',ev,.nil,.directory~new,.array~of('SymPy provider is not registered.'),claim,assumptions,'INDETERMINATE')
  end
  return p~proveEquals(expression,claim,assumptions)

::class MathProofPlanner public
::method _defaultClaim class
  use strict arg value
  if value~isA(.MathRational) then return .MathClaim~isExact
  if value~isA(.MathBall) | value~isA(.MathInterval) then return .MathClaim~enclosesExactEvaluation
  if value~isA(.MathExpression) then return .MathClaim~equals(0)
  return .MathClaim~independentlyReproduced

::method _policy class
  use strict arg policy
  if policy == .nil then return .MathProofPolicy~standard
  if policy~isA(.MathProofPolicy) then return policy
  name=policy~string~upper
  select
    when name='STANDARD' then return .MathProofPolicy~standard
    when name='STRONG' then return .MathProofPolicy~strong
    when name='CERTIFIED' then return .MathProofPolicy~certified
    when name='DIAGNOSTIC' then return .MathProofPolicy~diagnostic
    otherwise raise syntax 88.900 array('MathProofPolicy or STANDARD/STRONG/CERTIFIED/DIAGNOSTIC',policy)
  end

::method plan class
  use strict arg value, claim=.nil, assumptions=.nil, policy=.nil
  if claim == .nil then claim=self~_defaultClaim(value)
  if assumptions == .nil then assumptions=.MathAssumptions~new
  policy=self~_policy(policy)
  plan=.MathProofPlan~new(claim,assumptions,policy)

  if value~isA(.MathRational) then do
    if claim~kind='IS_EXACT' | claim~kind='EQUALS' then plan~addRoute(.MathProofRoute~new('RATIONAL-EXACT','OBLIGATION','PURE','EXACT','PURE,RATIONAL,INTEGER-GCD','normalized rational representation directly decides the claim'))
    return plan
  end
  if value~isA(.MathBall) then do
    if claim~kind='ENCLOSES_EXACT_EVALUATION' | claim~kind='RELATIVE_ACCURACY_BITS' then plan~addRoute(.MathProofRoute~new('BALL-CERTIFICATE','OBLIGATION',value~provider,'RIGOROUS_BALL_ENCLOSURE','PYTHON-FLINT,ARB,BALL','use the retained rigorous ball certificate'))
    return plan
  end
  if value~isA(.MathInterval) then do
    if claim~kind='ENCLOSES_EXACT_EVALUATION' | claim~kind='CONTAINS' then plan~addRoute(.MathProofRoute~new('INTERVAL-CERTIFICATE','OBLIGATION',value~evidence~primaryProvider,'RIGOROUS_CONTAINMENT_FOR_SUPPORTED_DIRECT_ARITHMETIC','MPMATH,INTERVAL','use the retained interval enclosure and its scoped guarantee'))
    return plan
  end
  if value~isA(.MathExpression) then do
    if claim~kind='EQUALS' then do
      p=.Maths~provider('SYMPY')
      if p \== .nil then plan~addRoute(.MathProofRoute~new('SYMPY-SYMBOLIC','OBLIGATION','SYMPY','EXACT_IF_SYMBOLIC_ZERO','SYMPY,SYMBOLIC','independent CAS simplification of the claimed difference'))
      if p == .nil | policy~runAll then plan~addRoute(.MathProofRoute~new('LOCAL-STRUCTURAL','OBLIGATION','PURE','EXACT_IF_REDUCED_TO_ZERO','PURE,SYMBOLIC,STRUCTURAL','small local sound rewrite set provides an implementation-distinct witness'))
    end
    return plan
  end
  if claim~kind='INDEPENDENT_REPRODUCTION' then do
    plan~addRoute(.MathProofRoute~new('REFERENCE-RECOMPUTE','OBLIGATION','REFERENCE','INDEPENDENT_RECOMPUTATION','REFERENCE,HIGH-PRECISION','replay the derivation using a distinct provider/algorithm at verification precision'))
    return plan
  end
  if claim~kind='SATISFIES_EQUATION' then do
    if policy~certifiedOnly | policy~runAll then do
      if rx_math_can_exact_residual(value) then plan~addRoute(.MathProofRoute~new('EXACT-REPRESENTED-RESIDUAL','OBLIGATION','PURE','EXACT_BOUND_ON_REPRESENTED_VALUES','PURE,RATIONAL,EXACT-RESIDUAL','convert retained Maths values to exact rationals and decide the residual bound without floating-point arithmetic'))
    end
    if \policy~certifiedOnly then plan~addRoute(.MathProofRoute~new('NUMERICAL-RESIDUAL','OBLIGATION','PURE','NUMERICAL_RESIDUAL_BOUND','PURE,DECIMAL,RESIDUAL','evaluate the defining equation residual at verification precision'))
    if policy~requireCorroboration then plan~addRoute(.MathProofRoute~new('REFERENCE-SUPPORT','SUPPORT','REFERENCE','INDEPENDENT_RECOMPUTATION','REFERENCE,HIGH-PRECISION','supporting diagnostic: independently recompute the solution; this is not the same claim',.MathClaim~independentlyReproduced))
    return plan
  end
  return plan

::method recompute class
  use strict arg value
  deriv=value~derivation
  if deriv == .nil then return .nil
  operation=deriv~operation; ops=deriv~operands; ctx=value~context~verificationContext
  provider=.Maths~provider('REFERENCE')
  select
    when operation='matrix.add' then return provider~matrixAdd(ops[1],ops[2],ctx)
    when operation='matrix.sub' then return provider~matrixSub(ops[1],ops[2],ctx)
    when operation='matrix.matmul' then return provider~matrixMul(ops[1],ops[2],ctx)
    when operation='matrix.solve' then return provider~matrixSolve(ops[1],ops[2],ctx)
    otherwise return .nil
  end

::method prove class
  use strict arg value, claim=.nil, assumptions=.nil, policy=.nil
  plan=self~plan(value,claim,assumptions,policy)
  attempts=.array~new
  if plan~routeCount=0 then do
    ev=self~_baseEvidence(value,plan~claim)
    notes=.array~of('No proof route is registered that can establish this claim under policy 'plan~policy~name'.')
    if plan~claim~kind='ACCURATE_DIGITS' then notes~append('Accuracy-to-N-digits requires an operation-specific certified forward-error bound; duplicate approximations are not promoted to proof.')
    checks=.directory~new; checks['plannerPolicy']=plan~policy~name; checks['attemptCount']=0
    return .MathProof~new('UNVERIFIED',ev,.nil,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
  end
  do route over plan~routes
    routeClaim=route~claim
    if routeClaim == .nil then routeClaim=plan~claim
    pr=self~_executeRoute(value,route,routeClaim,plan~assumptions)
    attempts~append(.MathProofAttempt~new(route,pr))
    if \plan~policy~runAll & route~role='OBLIGATION' & pr~outcome='PROVED' then leave
  end
  return self~_finalize(value,plan,attempts)

::method _executeRoute class
  use strict arg value,route,claim,assumptions
  select
    when route~id='RATIONAL-EXACT' then return .MathDirectProof~rational(value,claim,assumptions)
    when route~id='BALL-CERTIFICATE' then return .MathDirectProof~ball(value,claim,assumptions)
    when route~id='INTERVAL-CERTIFICATE' then return .MathDirectProof~interval(value,claim,assumptions)
    when route~id='SYMPY-SYMBOLIC' then return .MathDirectProof~expressionSympy(value,claim,assumptions)
    when route~id='LOCAL-STRUCTURAL' then return .MathDirectProof~expressionLocal(value,claim,assumptions)
    when route~id='REFERENCE-RECOMPUTE' then return self~_proveIndependent(value,claim,assumptions)
    when route~id='NUMERICAL-RESIDUAL' then return self~_proveEquation(value,claim,assumptions)
    when route~id='EXACT-REPRESENTED-RESIDUAL' then return self~_proveEquationExact(value,claim,assumptions)
    when route~id='REFERENCE-SUPPORT' then return self~_proveIndependent(value,claim,assumptions)
    otherwise return .MathProof~new('UNVERIFIED',self~_baseEvidence(value,claim),.nil,.directory~new,.array~of('Unknown proof route 'route~id'.'),claim,assumptions,'INDETERMINATE')
  end

::method _finalize class
  use strict arg value,plan,attempts
  proved=.array~new; disproved=.array~new; supportProved=.array~new; supportFailed=.array~new
  best=.nil; bestRank=-1
  do attempt over attempts
    if attempt~route~role='OBLIGATION' then do
      if attempt~outcome='PROVED' then do
        proved~append(attempt)
        rank=rx_math_strength_rank(attempt~strength)
        if rank>bestRank then do; best=attempt; bestRank=rank; end
      end
      else if attempt~outcome='DISPROVED' then disproved~append(attempt)
    end
    else do
      if attempt~outcome='PROVED' then supportProved~append(attempt)
      else if attempt~outcome='DISPROVED' then supportFailed~append(attempt)
    end
  end
  checks=.directory~new
  checks['plannerPolicy']=plan~policy~name; checks['attemptCount']=attempts~items
  checks['obligationProved']=proved~items; checks['obligationDisproved']=disproved~items
  checks['supportProved']=supportProved~items; checks['supportFailed']=supportFailed~items
  notes=.array~new
  do attempt over attempts
    notes~append('Planner route 'attempt~route~id' ('attempt~route~role') returned 'attempt~outcome' / 'attempt~strength'.')
  end

  if proved~items>0 & disproved~items>0 then do
    notes~append('Proof obligations produced conflicting decisive outcomes. The planner refuses to choose a convenient answer.')
    return .MathProof~new('EVIDENCE_CONFLICT',best~proof~primaryEvidence,.nil,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
  end

  if proved~items>0 then do
    bp=best~proof
    do name over bp~checks~allIndexes; checks[name]=bp~checks[name]; end
    corroborated=rx_math_proof_corroborated(proved,supportProved,bp)
    checks['corroborated']=corroborated
    if plan~policy~certifiedOnly & \rx_math_is_certifying_strength(bp~status) then do
      notes~append('The claim has supporting evidence, but policy CERTIFIED requires exact/symbolic/rigorous enclosure or exact-bound certification.')
      return .MathProof~new('INSUFFICIENT_CERTIFICATION',bp~primaryEvidence,bp~verificationEvidence,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
    end
    if plan~policy~requireCorroboration then do
      supportPlanned=0
      do r over plan~routes; if r~role='SUPPORT' then supportPlanned+=1; end
      checks['supportPlanned']=supportPlanned
      if supportPlanned>0 & supportProved~items=0 then do
        notes~append('Policy STRONG requested an independent supporting route and it did not succeed. This does not disprove the stated obligation; it prevents the stronger policy from declaring the evidence sufficient.')
        return .MathProof~new('CORROBORATION_REQUIRED',bp~primaryEvidence,bp~verificationEvidence,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
      end
      if supportPlanned=0 & plan~routeCount>1 & \corroborated then do
        notes~append('Policy STRONG planned materially different corroboration, but that corroboration did not succeed. The proved obligation remains evidence, but the strong-policy result is INDETERMINATE.')
        return .MathProof~new('CORROBORATION_REQUIRED',bp~primaryEvidence,bp~verificationEvidence,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
      end
    end
    do n over bp~notes; notes~append(n); end
    verification=bp~verificationEvidence
    if verification == .nil & supportProved~items>0 then do
      verification=supportProved[1]~proof~verificationEvidence
      if verification == .nil then verification=supportProved[1]~proof~primaryEvidence
    end
    if verification == .nil & proved~items>1 then do
      do alt over proved
        if alt~route~id<>best~route~id then do; verification=alt~proof~primaryEvidence; leave; end
      end
    end
    return .MathProof~new(bp~status,bp~primaryEvidence,verification,checks,notes,plan~claim,plan~assumptions,'PROVED',plan,attempts)
  end

  if disproved~items>0 then do
    dp=disproved[1]~proof
    do name over dp~checks~allIndexes; checks[name]=dp~checks[name]; end
    do n over dp~notes; notes~append(n); end
    return .MathProof~new(dp~status,dp~primaryEvidence,dp~verificationEvidence,checks,notes,plan~claim,plan~assumptions,'DISPROVED',plan,attempts)
  end

  ev=self~_baseEvidence(value,plan~claim)
  if attempts~items>0 then ev=attempts[1]~proof~primaryEvidence
  notes~append('No planned proof obligation established or disproved the claim.')
  return .MathProof~new('UNVERIFIED',ev,.nil,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)

::method _baseEvidence class
  use strict arg value,claim
  if value~isA(.MathValue) then if value~evidence \== .nil then return value~evidence
  return .MathEvidence~new('proof.plan',value~context,.array~of(claim~canonical))

::method _proveIndependent class
  use strict arg value,claim,assumptions
  if \value~isA(.MathValue) then return .MathProof~new('UNVERIFIED',self~_baseEvidence(value,claim),.nil,.directory~new,.array~of('Independent recomputation requires a derived MathValue.'),claim,assumptions,'INDETERMINATE')
  if value~evidence == .nil then return .MathProof~new('UNVERIFIED',.MathEvidence~new('unknown',value~context),.nil,.nil,.nil,claim,assumptions,'INDETERMINATE')
  alternate=self~recompute(value)
  if alternate == .nil then return .MathProof~new('UNVERIFIED',value~evidence,.nil,.directory~new,.array~of('No independent recomputation path is registered for this derivation in v0.7.'),claim,assumptions,'INDETERMINATE')
  checks=.directory~new; notes=.array~new
  if value~isA(.MathMatrix) then diff=value~maxAbsDifference(alternate)
  else if value~isA(.MathVector) then diff=rx_math_vector_max_abs_difference(value,alternate)
  else diff='INF'
  checks['maxAbsDifference']=diff
  if value~evidence~steps~items>0 & alternate~evidence~steps~items>0 then do
    checks['primaryProvider']=value~evidence~steps[1]~provider
    checks['primaryAlgorithm']=value~evidence~steps[1]~algorithm
    checks['verificationProvider']=alternate~evidence~steps[1]~provider
    checks['verificationAlgorithm']=alternate~evidence~steps[1]~algorithm
    checks['differentProvider']=value~evidence~steps[1]~provider<>alternate~evidence~steps[1]~provider
    checks['differentAlgorithm']=value~evidence~steps[1]~algorithm<>alternate~evidence~steps[1]~algorithm
  end
  tol=claim~parameter; if tol == .nil then tol=value~context~relativeTolerance
  numeric digits value~context~verificationContext~workingDigits
  if diff='INF' then do; status='DISAGREEMENT'; outcome='DISPROVED'; end
  else if rx_math_le(diff,tol,value~context) then do
    if value~context~numberDomain='RATIONAL' then status='EXACTLY_REPRODUCED'; else status='VERIFIED_NUMERICALLY'
    outcome='PROVED'
  end
  else do; status='DISAGREEMENT'; outcome='DISPROVED'; end
  if value~derivation \== .nil then if value~derivation~operation='matrix.solve' then do
    a=value~derivation~operands[1]; b=value~derivation~operands[2]
    residual=rx_math_residual_norm_inf(a,value,b,value~context~verificationContext)
    checks['residualInf']=residual; checks['verificationResidualInf']=alternate~evidence~checks['residualInf']
    if \rx_math_le(residual,tol,value~context) then do; status='DISAGREEMENT'; outcome='DISPROVED'; end
  end
  if value~context~numberDomain='RATIONAL' then notes~append('Independent recomputation used provider REFERENCE through a distinct exact Gauss-Jordan path in the same exact rational domain.')
  else notes~append('Independent recomputation used provider REFERENCE at increased decimal precision.')
  notes~append('The outcome applies only to the stated INDEPENDENT_REPRODUCTION claim and declared tolerance; it is not a theorem that the numerical value is exact.')
  return .MathProof~new(status,value~evidence,alternate~evidence,checks,notes,claim,assumptions,outcome)

::method _proveEquation class
  use strict arg value,claim,assumptions
  checks=.directory~new; notes=.array~new
  if value~derivation == .nil | value~derivation~operation<>'matrix.solve' then do
    notes~append('SATISFIES_EQUATION is currently registered for matrix.solve derivations.')
    return .MathProof~new('UNVERIFIED',self~_baseEvidence(value,claim),.nil,checks,notes,claim,assumptions,'INDETERMINATE')
  end
  a=value~derivation~operands[1]; b=value~derivation~operands[2]
  ctx=value~context~verificationContext
  residual=rx_math_residual_norm_inf(a,value,b,ctx); checks['residualInf']=residual
  tol=claim~parameter; if tol == .nil then tol=value~context~absoluteTolerance
  checks['tolerance']=tol
  ev=.MathEvidence~new('matrix.solve.residual',ctx,.array~of(a~canonical,value~canonical,b~canonical))
  if ctx~numberDomain='RATIONAL' then do; guarantee='EXACT'; wd='dynamic-integer'; end
  else do; guarantee='APPROXIMATE_RESIDUAL_EVALUATION'; wd=ctx~workingDigits; end
  ev~addStep(.MathPathStep~new('matrix.solve.residual','PURE','0.7','direct-equation-residual-inf-norm',ctx~numberDomain,wd,rx_math_representation(ctx),'Re-evaluates A*x-b from the retained Maths values; this evidence is separate from the path that originally produced x.',guarantee,'PURE,'ctx~numberDomain',RESIDUAL'))
  ev~putCheck('residualInf',residual); ev~putCheck('tolerance',tol)
  if value~evidence \== .nil then ev~putCheck('sourceResultProvider',value~evidence~primaryProvider)
  if rx_math_le(residual,tol,value~context) then do
    if value~context~numberDomain='RATIONAL' & rx_math_is_zero(residual,value~context) then do
      notes~append('The defining equation residual is exactly zero in normalized rational arithmetic; successful exact elimination established nonzero pivots for this square system.')
      return .MathProof~new('EXACT',ev,.nil,checks,notes,claim,assumptions,'PROVED')
    end
    notes~append('This establishes a bounded numerical residual claim only; it does not establish exact equality, forward accuracy, or uniqueness of solution.')
    return .MathProof~new('NUMERICALLY_SATISFIED',ev,.nil,checks,notes,claim,assumptions,'PROVED')
  end
  notes~append('The defining equation residual exceeds the claimed tolerance.')
  return .MathProof~new('DISPROVED',ev,.nil,checks,notes,claim,assumptions,'DISPROVED')

::method _proveEquationExact class
  use strict arg value,claim,assumptions
  checks=.directory~new; notes=.array~new
  if \rx_math_can_exact_residual(value) then do
    notes~append('The current Maths objects cannot be parsed into the exact rational replay lane.')
    return .MathProof~new('UNVERIFIED',self~_baseEvidence(value,claim),.nil,checks,notes,claim,assumptions,'INDETERMINATE')
  end
  deriv=value~derivation; a=deriv~operands[1]; b=deriv~operands[2]
  rctx=.MathContext~rational
  residual=rx_math_exact_residual_norm_inf(a,value,b,rctx)
  tol=claim~parameter; if tol == .nil then tol=value~context~absoluteTolerance
  rt=.MathRational~coerce(tol,rctx)
  checks['residualExact']=residual~canonical; checks['toleranceExact']=rt~canonical
  ev=.MathEvidence~new('matrix.solve.residual.exact-replay',rctx,.array~of(a~canonical,value~canonical,b~canonical))
  ev~addStep(.MathPathStep~new('matrix.solve.residual.exact-replay','PURE','0.7','exact-rational-residual-over-represented-values','RATIONAL','dynamic-integer','normalized exact rationals','All values are reconstructed from the decimal/rational text retained by the Maths objects. This certifies the represented values; it cannot recover precision already lost before those values were retained.','EXACT_BOUND_ON_REPRESENTED_VALUES','PURE,RATIONAL,EXACT-RESIDUAL'))
  ev~putCheck('residualExact',residual~canonical); ev~putCheck('toleranceExact',rt~canonical)
  if value~evidence \== .nil then ev~putCheck('sourceResultProvider',value~evidence~primaryProvider)
  notes~append('The residual inequality is decided exactly in rational arithmetic over the values retained by the Maths objects.')
  if value~context~numberDomain='BINARY64' then notes~append('Scope warning: exact replay certifies the materialized binary64 values represented in the Maths object, not any higher-precision source values that existed before binary64 conversion.')
  if residual~compareTo(rt)<=0 then outcome='PROVED'; else outcome='DISPROVED'
  if outcome='PROVED' then strength='EXACT_BOUND_CERTIFIED'; else strength='DISPROVED'
  return .MathProof~new(strength,ev,.nil,checks,notes,claim,assumptions,outcome)

::class MathExpressionProofPlanner public
::method prove class
  use strict arg expression,claim,assumptions=.nil,policy=.nil
  return .MathProofPlanner~prove(expression,claim,assumptions,policy)

::routine rx_math_check_same_shape public
  use strict arg left,right
  if \right~isA(.MathMatrix) then raise syntax 88.900 array('MathMatrix',right~class~id)
  if left~rows<>right~rows | left~cols<>right~cols then raise syntax 88.900 array('equal matrix dimensions',left~rows'x'left~cols'/'right~rows'x'right~cols)
  return

::routine rx_math_vector_max_abs_difference public
  use strict arg left,right
  if left~size<>right~size then return 'INF'
  numeric digits max(left~context~workingDigits,right~context~workingDigits)
  m=rx_math_zero(left~context)
  do i=1 to left~size
    d=(left[i]-right[i])~abs; if rx_math_compare(d,m,left~context)>0 then m=d
  end
  return m

::routine rx_math_residual_norm_inf public
  use strict arg a,x,b,context
  numeric digits context~workingDigits
  if \x~isA(.MathVector) | \b~isA(.MathVector) then return 'INF'
  m=rx_math_zero(context)
  do i=1 to a~rows
    s=rx_math_zero(context); do j=1 to a~cols; s=s+a[i,j]*x[j]; end
    d=(s-b[i])~abs; if rx_math_compare(d,m,context)>0 then m=d
  end
  return m


::routine rx_math_can_coerce_rational public
  use strict arg value
  if value~isA(.MathRational) then return .true
  s=value~string~strip
  if s='' then return .false
  if s~pos('(')>0 | s~pos(')')>0 then return rx_math_is_repeating_decimal_text(s)
  slash=s~pos('/')
  if slash>0 then do
    if s~substr(slash+1)~pos('/')>0 then return .false
    return rx_math_is_integer_text(s~left(slash-1)~strip) & rx_math_is_integer_text(s~substr(slash+1)~strip)
  end
  return rx_math_exact_decimal_text(value)

::routine rx_math_is_repeating_decimal_text public
  use strict arg value
  s=value~string~strip
  if s='' then return .false
  if s~left(1)='+' | s~left(1)='-' then s=s~substr(2)
  if s='' then return .false
  open=s~pos('(')
  if open=0 | s~right(1)<>')' then return .false
  if s~substr(open+1)~pos('(')>0 then return .false
  prefix=s~left(open-1); repeat=s~substr(open+1,s~length-open-1)
  if repeat='' | \rx_math_is_unsigned_digits(repeat) then return .false
  dot=prefix~pos('.')
  if dot=0 | prefix~substr(dot+1)~pos('.')>0 then return .false
  whole=prefix~left(dot-1); nonrep=prefix~substr(dot+1)
  if whole='' | \rx_math_is_unsigned_digits(whole) then return .false
  if nonrep<>'' then if \rx_math_is_unsigned_digits(nonrep) then return .false
  return .true

::routine rx_math_exact_decimal_text public
  use strict arg value
  if value~isA(.MathRational) then return .true
  s=value~string~strip
  if s='' then return .false
  if s~left(1)='+' | s~left(1)='-' then s=s~substr(2)
  if s='' then return .false
  parse upper var s mant 'E' exponent
  if exponent<>'' then if \rx_math_is_signed_integer_text(exponent) then return .false
  dot=mant~pos('.')
  if dot>0 then mant=mant~left(dot-1)||mant~substr(dot+1)
  return rx_math_is_unsigned_digits(mant)

::routine rx_math_can_exact_residual public
  use strict arg value
  if \value~isA(.MathVector) then return .false
  if value~derivation == .nil then return .false
  if value~derivation~operation<>'matrix.solve' then return .false
  a=value~derivation~operands[1]; b=value~derivation~operands[2]
  if \a~isA(.MathMatrix) | \b~isA(.MathVector) then return .false
  do i=1 to a~rows
    do j=1 to a~cols
      if \rx_math_exact_decimal_text(a[i,j]) then return .false
    end
  end
  do i=1 to b~size
    if \rx_math_exact_decimal_text(b[i]) then return .false
  end
  do i=1 to value~size
    if \rx_math_exact_decimal_text(value[i]) then return .false
  end
  return .true

::routine rx_math_exact_residual_norm_inf public
  use strict arg a,x,b,context
  m=.MathRational~of(0,1,context)
  do i=1 to a~rows
    sum=.MathRational~of(0,1,context)
    do j=1 to a~cols
      av=.MathRational~coerce(a[i,j],context); xv=.MathRational~coerce(x[j],context)
      sum=sum+(av*xv)
    end
    bv=.MathRational~coerce(b[i],context); d=(sum-bv)~abs
    if d~compareTo(m)>0 then m=d
  end
  return m

::routine rx_math_strength_rank public
  use strict arg strength
  select
    when strength='EXACT' then return 100
    when strength='EXACT_BOUND_CERTIFIED' then return 95
    when strength='SYMBOLICALLY_PROVED' then return 90
    when strength='BALL_CERTIFIED' then return 85
    when strength='INTERVAL_CERTIFIED' then return 80
    when strength='EXACTLY_REPRODUCED' then return 75
    when strength='VERIFIED_NUMERICALLY' then return 60
    when strength='NUMERICALLY_SATISFIED' then return 55
    when strength='INTERVAL_MEMBERSHIP' then return 50
    otherwise return 0
  end

::routine rx_math_is_certifying_strength public
  use strict arg strength
  return strength='EXACT' | strength='EXACT_BOUND_CERTIFIED' | strength='SYMBOLICALLY_PROVED' | strength='BALL_CERTIFIED' | strength='INTERVAL_CERTIFIED' | strength='EXACTLY_REPRODUCED'

::routine rx_math_proof_corroborated public
  use strict arg proved,supportProved,bestProof
  if bestProof~status='VERIFIED_NUMERICALLY' | bestProof~status='EXACTLY_REPRODUCED' then return .true
  if supportProved~items>0 then return .true
  if proved~items<2 then return .false
  do i=1 to proved~items-1
    a=proved[i]~proof~primaryEvidence
    if a == .nil | a~steps~items=0 then iterate
    do j=i+1 to proved~items
      b=proved[j]~proof~primaryEvidence
      if b == .nil | b~steps~items=0 then iterate
      if a~steps[1]~provider<>b~steps[1]~provider & a~steps[1]~algorithm<>b~steps[1]~algorithm then return .true
    end
  end
  return .false

::routine rx_math_valid_symbol_name public
  use strict arg name
  s=name~string
  if s='' then return .false
  first=s~substr(1,1)
  if \(datatype(first,'A') | first='_') then return .false
  do i=2 to s~length
    ch=s~substr(i,1)
    if \(datatype(ch,'A') | datatype(ch,'W') | ch='_') then return .false
  end
  return .true

::routine rx_math_coerce_value public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then return .MathRational~coerce(value,context)
  numeric digits context~workingDigits
  return value+0

::routine rx_math_scalar_for_context public
  use strict arg value,context,expectation='numeric scalar'
  if context~numberDomain='RATIONAL' then return .MathRational~coerce(value,context)
  if \datatype(value,'N') then raise syntax 88.900 array(expectation,value)
  numeric digits context~workingDigits
  return value+0

::routine rx_math_zero public
  use strict arg context
  if context~numberDomain='RATIONAL' then return .MathRational~of(0,1,context)
  return 0

::routine rx_math_is_zero public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then return .MathRational~coerce(value,context)~numerator=0
  return value=0

::routine rx_math_compare public
  use strict arg a,b,context
  if context~numberDomain='RATIONAL' then return .MathRational~coerce(a,context)~compareTo(.MathRational~coerce(b,context))
  if a<b then return -1
  if a>b then return 1
  return 0

::routine rx_math_le public
  use strict arg a,b,context
  return rx_math_compare(a,b,context)<=0

::routine rx_math_representation public
  use strict arg context
  if context~numberDomain='RATIONAL' then return 'ooRexx normalized exact rational objects'
  if context~numberDomain='BINARY64' then return 'IEEE-754 binary64'
  return 'ooRexx decimal arithmetic'

::routine rx_math_is_unsigned_digits public
  use strict arg text
  s=text~string
  if s='' then return .false
  do i=1 to s~length
    if \datatype(s~substr(i,1),'W') then return .false
  end
  return .true

::routine rx_math_is_signed_integer_text public
  use strict arg text
  s=text~string~strip
  if s='' then return .false
  if s~left(1)='+' | s~left(1)='-' then s=s~substr(2)
  return rx_math_is_unsigned_digits(s)

::routine rx_math_is_integer_text public
  use strict arg text
  return rx_math_is_signed_integer_text(text)

::routine rx_math_integer_text_digits public
  use strict arg value
  s=value~string~strip
  if s~left(1)='+' | s~left(1)='-' then s=s~substr(2)
  do while s~length>1 & s~left(1)='0'; s=s~substr(2); end
  return s~length

::routine rx_math_integer_work_digits public
  use strict arg a,b
  return max(rx_math_integer_text_digits(a),rx_math_integer_text_digits(b))

::routine rx_math_normalize_fraction public
  use strict arg numerator,denominator
  nt=numerator~string~strip; dt=denominator~string~strip
  if \rx_math_is_integer_text(nt) then raise syntax 88.900 array('integer numerator',nt)
  if \rx_math_is_integer_text(dt) then raise syntax 88.900 array('non-zero integer denominator',dt)
  work=rx_math_integer_work_digits(nt,dt)+8
  if work<32 then work=32
  numeric digits work
  n=nt+0; d=dt+0
  if d=0 then raise syntax 42.3
  if d<0 then do; n=0-n; d=0-d; end
  g=rx_math_integer_gcd(n,d,work)
  n=n/g; d=d/g
  return .array~of(n,d)

::routine rx_math_integer_gcd public
  use strict arg a,b,digits=50
  numeric digits digits
  a=a~abs; b=b~abs
  do while b<>0
    t=a//b; a=b; b=t
  end
  if a=0 then return 1
  return a

::routine rx_math_rational_binary_digits public
  use strict arg a,b
  da=rx_math_integer_text_digits(a~numerator)+rx_math_integer_text_digits(a~denominator)
  db=rx_math_integer_text_digits(b~numerator)+rx_math_integer_text_digits(b~denominator)
  return da+db

::routine max public
  use strict arg a,b
  if a>b then return a
  return b

/* -------------------------------------------------------------------------
 * Quantized mathematical representations.
 *
 * The PURE implementation is a correctness/reference path, not a speed path.
 * It reconstructs the values presented to Maths as exact rationals and does
 * block scaling and code selection with exact rational/integer arithmetic.
 * This characterizes quantization error over the retained represented values.
 * ------------------------------------------------------------------------- */

::class MathDType public
::method init
  expose _name _bits _kind _exact
  use strict arg name,bits,kind='NUMERIC',exact=.false
  _name=name~string~upper; _bits=bits; _kind=kind~string~upper; _exact=exact
::method name; expose _name; return _name
::method bits; expose _bits; return _bits
::method kind; expose _kind; return _kind
::method exact; expose _exact; return _exact
::method canonical; expose _name _bits _kind _exact; return 'dtype[name='_name';bits='_bits';kind='_kind';exact='_exact']'
::method string; expose _name; return _name
::method of class
  use strict arg name
  key=name~string~upper
  select
    when key='INT8' then return self~new('INT8',8,'INTEGER',.true)
    when key='UINT8' then return self~new('UINT8',8,'INTEGER',.true)
    when key='FLOAT16' | key='FP16' then return self~new('FLOAT16',16,'BINARY_FLOAT',.false)
    when key='BFLOAT16' | key='BF16' then return self~new('BFLOAT16',16,'BINARY_FLOAT',.false)
    when key='FLOAT32' | key='FP32' then return self~new('FLOAT32',32,'BINARY_FLOAT',.false)
    when key='FLOAT64' | key='FP64' | key='DOUBLE' then return self~new('FLOAT64',64,'BINARY_FLOAT',.false)
    when key='RATIONAL' | key='EXACT_RATIONAL' then return self~new('RATIONAL',0,'EXACT_RATIONAL',.true)
    otherwise raise syntax 88.900 array('known Maths dtype',name)
  end
::method int8 class; return self~of('INT8')
::method uint8 class; return self~of('UINT8')
::method float16 class; return self~of('FLOAT16')
::method bfloat16 class; return self~of('BFLOAT16')
::method float32 class; return self~of('FLOAT32')
::method float64 class; return self~of('FLOAT64')
::method rational class; return self~of('RATIONAL')

::class MathQuantizationCodebook public
::method init
  expose _name _values _lineage
  use strict arg name,values,lineage='CUSTOM'
  if \values~isA(.array) | values~items<2 then raise syntax 88.900 array('quantization codebook Array with at least two values',values)
  _name=name~string~upper; _lineage=lineage~string
  _values=.array~new
  do value over values; _values~append(.MathRational~coerce(value,.MathContext~rational)); end
::method name; expose _name; return _name
::method lineage; expose _lineage; return _lineage
::method size; expose _values; return _values~items
::method at; expose _values; use strict arg index; return _values[index]
::method values
  expose _values
  out=.array~new; do v over _values; out~append(v); end; return out
::method nearestIndex
  expose _values
  use strict arg value
  v=.MathRational~coerce(value,.MathContext~rational)
  best=1; bestDiff=(v-_values[1])~abs
  do i=2 to _values~items
    d=(v-_values[i])~abs
    if d~compareTo(bestDiff)<0 then do; best=i; bestDiff=d; end
  end
  return best
::method canonical
  expose _name _values _lineage
  s='codebook[name='_name';lineage='_lineage';values='
  first=.true
  do v over _values; if \first then s=s','; first=.false; s=s||v~string; end
  return s']'
::method string; expose _name; return _name
::method nf4 class
  values=.array~of( -
    '-1.0','-0.6961928009986877','-0.5250730514526367','-0.39491748809814453', -
    '-0.28444138169288635','-0.18477343022823334','-0.09105003625154495','0.0', -
    '0.07958029955625534','0.16093020141124725','0.24611230194568634','0.33791524171829224', -
    '0.44070982933044434','0.5626170039176941','0.7229568362236023','1.0')
  return self~new('NF4-BNB-CODEBOOK',values,'bitsandbytes NF4 published 16-value codebook; decimal constants retained exactly by Maths')

::class MathQuantizationScheme public
::method init
  expose _name _bits _blockSize _storageType _computeType _codebook _nested _rounding _providerHint
  use strict arg name,bits,blockSize=64,storageType='INT8',computeType='FLOAT32',codebook=.nil,nested=.false,rounding='NEAREST_EVEN',providerHint='PURE'
  if \datatype(bits,'W') | bits<1 then raise syntax 88.900 array('positive quantization bits',bits)
  if \datatype(blockSize,'W') | blockSize<1 then raise syntax 88.900 array('positive quantization block size',blockSize)
  _name=name~string~upper; _bits=bits; _blockSize=blockSize
  _storageType=.MathDType~of(storageType); _computeType=.MathDType~of(computeType)
  _codebook=codebook; _nested=nested; _rounding=rounding~string~upper; _providerHint=providerHint~string~upper
::method name; expose _name; return _name
::method bits; expose _bits; return _bits
::method blockSize; expose _blockSize; return _blockSize
::method storageType; expose _storageType; return _storageType
::method computeType; expose _computeType; return _computeType
::method codebook; expose _codebook; return _codebook
::method nested; expose _nested; return _nested
::method rounding; expose _rounding; return _rounding
::method providerHint; expose _providerHint; return _providerHint
::method isCodebook; expose _codebook; return _codebook \== .nil
::method canonical
  expose _name _bits _blockSize _storageType _computeType _codebook _nested _rounding _providerHint
  cb='NONE'; if _codebook \== .nil then cb=_codebook~name
  return 'quantization[name='_name';bits='_bits';blockSize='_blockSize';storage='_storageType~name';compute='_computeType~name';codebook='cb';nested='_nested';rounding='_rounding';providerHint='_providerHint']'
::method string; expose _name; return _name
::method int8 class
  use strict arg blockSize=64,computeType='FLOAT32'
  return self~new('SYMMETRIC_INT8',8,blockSize,'INT8',computeType,.nil,.false,'NEAREST_EVEN','PURE')
::method nf4 class
  use strict arg blockSize=64,computeType='BFLOAT16',nested=.false
  return self~new('NF4',4,blockSize,'UINT8',computeType,.MathQuantizationCodebook~nf4,nested,'NEAREST_CODE_LOWER_TIE','BITSANDBYTES-CONCEPT')

::class MathQuantizationState public
::method init
  expose _scheme _shape _scales _sourceContext _provider _providerVersion _maxAbsError _maxErrorBound _sourceCanonical _details
  use strict arg scheme,shape,scales,sourceContext,provider='PURE',providerVersion='0.7',maxAbsError=.nil,maxErrorBound=.nil,sourceCanonical='',details=''
  _scheme=scheme; _shape=shape~string; _scales=scales; _sourceContext=sourceContext
  _provider=provider~string~upper; _providerVersion=providerVersion~string
  _maxAbsError=maxAbsError; _maxErrorBound=maxErrorBound; _sourceCanonical=sourceCanonical~string; _details=details~string
::method scheme; expose _scheme; return _scheme
::method shape; expose _shape; return _shape
::method scales; expose _scales; return _scales
::method sourceContext; expose _sourceContext; return _sourceContext
::method provider; expose _provider; return _provider
::method providerVersion; expose _providerVersion; return _providerVersion
::method maxAbsError; expose _maxAbsError; return _maxAbsError
::method maxErrorBound; expose _maxErrorBound; return _maxErrorBound
::method sourceCanonical; expose _sourceCanonical; return _sourceCanonical
::method details; expose _details; return _details
::method canonical
  expose _scheme _shape _scales _sourceContext _provider _providerVersion _maxAbsError _maxErrorBound _details
  s='quantstate[scheme='_scheme~canonical';shape='_shape';provider='_provider';providerVersion='_providerVersion';sourceContext='_sourceContext~canonical';scales='
  first=.true; do v over _scales; if \first then s=s','; first=.false; s=s||v~string; end
  s=s';maxAbsError='_maxAbsError';maxErrorBound='_maxErrorBound';details='_details']'
  return s
::method string; return self~canonical

::class MathQuantizedVector subclass MathValue public
::method init
  expose _payload _state _sourceExact _size
  use strict arg payload,state,sourceExact,evidence=.nil,derivation=.nil
  self~init:super(state~sourceContext,evidence,derivation)
  _payload=payload; _state=state; _sourceExact=sourceExact; _size=sourceExact~items
::method payload; expose _payload; return _payload
::method state; expose _state; return _state
::method scheme; expose _state; return _state~scheme
::method size; expose _size; return _size
::method sourceExact; expose _sourceExact; return _sourceExact
::method maxAbsError; expose _state; return _state~maxAbsError
::method maxErrorBound; expose _state; return _state~maxErrorBound
::method dequantize
  use strict arg context=.nil
  if context == .nil then context=self~context
  return .MathQuantizer~dequantizeVector(self,context)
::method prove
  use strict arg claim=.nil,assumptions=.nil,policy=.nil
  if claim == .nil then claim=.MathClaim~quantizationErrorBelow(self~maxErrorBound)
  return .MathQuantizationProof~prove(self,claim,assumptions,policy)
::method '*'; use strict arg other; return self~dequantize * other
::method '+'; use strict arg other; return self~dequantize + other
::method '-'; use strict arg other; return self~dequantize - other
::method canonical; expose _state _payload; return 'qvector[state='_state~canonical';payload='rx_math_quant_payload_string(_payload)']'
::method string; return self~canonical

::class MathQuantizedMatrix subclass MathValue public
::method init
  expose _payload _state _sourceExact _rows _cols
  use strict arg payload,state,sourceExact,rows,cols,evidence=.nil,derivation=.nil
  self~init:super(state~sourceContext,evidence,derivation)
  _payload=payload; _state=state; _sourceExact=sourceExact; _rows=rows; _cols=cols
::method payload; expose _payload; return _payload
::method state; expose _state; return _state
::method scheme; expose _state; return _state~scheme
::method rows; expose _rows; return _rows
::method cols; expose _cols; return _cols
::method sourceExact; expose _sourceExact; return _sourceExact
::method maxAbsError; expose _state; return _state~maxAbsError
::method maxErrorBound; expose _state; return _state~maxErrorBound
::method dequantize
  use strict arg context=.nil
  if context == .nil then context=self~context
  return .MathQuantizer~dequantizeMatrix(self,context)
::method prove
  use strict arg claim=.nil,assumptions=.nil,policy=.nil
  if claim == .nil then claim=.MathClaim~quantizationErrorBelow(self~maxErrorBound)
  return .MathQuantizationProof~prove(self,claim,assumptions,policy)
::method '*'; use strict arg other; return self~dequantize * other
::method '+'; use strict arg other; return self~dequantize + other
::method '-'
  use strict arg other=.nil
  if arg(1,'O') then return self~dequantize * -1
  return self~dequantize - other
::method canonical; expose _state _payload _rows _cols; return 'qmatrix['_rows'x'_cols';state='_state~canonical';payload='rx_math_quant_payload_string(_payload)']'
::method string; return self~canonical

::class MathPrecisionPolicy public
::method init
  expose _minimumElements _protectedRoles _preserveExact
  use strict arg minimumElements=4096,preserveExact=.true
  if \datatype(minimumElements,'W') | minimumElements<0 then raise syntax 88.900 array('non-negative minimum quantization size',minimumElements)
  _minimumElements=minimumElements; _preserveExact=preserveExact; _protectedRoles=.directory~new
::method minimumElements; expose _minimumElements; return _minimumElements
::method preserveExact; expose _preserveExact; return _preserveExact
::method protect
  expose _protectedRoles
  use strict arg role
  _protectedRoles[role~string~upper]=.true; return self
::method isProtected
  expose _protectedRoles
  use strict arg role
  return _protectedRoles~hasIndex(role~string~upper)
::method shouldQuantize
  expose _minimumElements _preserveExact
  use strict arg elementCount,role='',exact=.false
  if _preserveExact & exact then return .false
  if role<>'' then if self~isProtected(role) then return .false
  return elementCount>=_minimumElements
::method canonical
  expose _minimumElements _protectedRoles _preserveExact
  s='precisionPolicy[minElements='_minimumElements';preserveExact='_preserveExact';protected='
  keys=.array~new; do k over _protectedRoles; keys~append(k); end; keys~sort
  first=.true; do k over keys; if \first then s=s','; first=.false; s=s||k; end
  return s']'

::class MathMixedPrecisionPlan public
::method init
  expose _defaultScheme _policy _highPrecisionType _outlierThreshold
  use strict arg defaultScheme,minimumElements=4096,highPrecisionType='FLOAT32',outlierThreshold=.nil
  _defaultScheme=defaultScheme; _policy=.MathPrecisionPolicy~new(minimumElements,.true); _highPrecisionType=.MathDType~of(highPrecisionType); _outlierThreshold=outlierThreshold
::method defaultScheme; expose _defaultScheme; return _defaultScheme
::method policy; expose _policy; return _policy
::method highPrecisionType; expose _highPrecisionType; return _highPrecisionType
::method outlierThreshold; expose _outlierThreshold; return _outlierThreshold
::method protect; expose _policy; use strict arg role; _policy~protect(role); return self
::method outliers
  expose _outlierThreshold
  use strict arg threshold
  _outlierThreshold=threshold; return self
::method shouldQuantize
  expose _policy
  use strict arg elementCount,role='',exact=.false
  return _policy~shouldQuantize(elementCount,role,exact)
::method canonical
  expose _defaultScheme _policy _highPrecisionType _outlierThreshold
  return 'mixedPrecision[default='_defaultScheme~canonical';high='_highPrecisionType~canonical';outlierThreshold='_outlierThreshold';policy='_policy~canonical']'
::method string; return self~canonical

::class MathQuantizer public
::method quantize class
  use strict arg value,scheme
  if scheme~nested then raise syntax 88.900 array('PURE reference quantizer without nested/double quantization; use nested=.false or a provider that explicitly supports nested state',scheme~canonical)
  if value~isA(.MathMatrix) then return self~quantizeMatrix(value,scheme)
  if value~isA(.MathVector) then return self~quantizeVector(value,scheme)
  raise syntax 88.900 array('MathMatrix or MathVector for quantization',value~class~id)
::method quantizeVector class
  use strict arg value,scheme
  source=.array~new
  do i=1 to value~size; source~append(rx_math_quant_exact(value[i])); end
  qres=rx_math_quantize_flat(source,scheme)
  state=.MathQuantizationState~new(scheme,'vector:'value~size,qres['scales'],value~context,'PURE','0.7',qres['maxError'],qres['maxBound'],value~canonical,qres['details'])
  ev=rx_math_quant_evidence('vector.quantize',value~context,value~canonical,scheme,state,qres)
  return .MathQuantizedVector~new(qres['payload'],state,source,ev,.MathDerivation~new('vector.quantize',.array~of(value),scheme))
::method quantizeMatrix class
  use strict arg value,scheme
  source=.array~new
  do r=1 to value~rows
    do c=1 to value~cols; source~append(rx_math_quant_exact(value[r,c])); end
  end
  qres=rx_math_quantize_flat(source,scheme)
  state=.MathQuantizationState~new(scheme,'matrix:'value~rows'x'value~cols,qres['scales'],value~context,'PURE','0.7',qres['maxError'],qres['maxBound'],value~canonical,qres['details'])
  ev=rx_math_quant_evidence('matrix.quantize',value~context,value~canonical,scheme,state,qres)
  return .MathQuantizedMatrix~new(qres['payload'],state,source,value~rows,value~cols,ev,.MathDerivation~new('matrix.quantize',.array~of(value),scheme))
::method dequantizeVector class
  use strict arg value,context
  flat=rx_math_dequantize_flat(value~payload,value~state)
  out=.array~new; do v over flat; out~append(rx_math_quant_to_context(v,context)); end
  ev=rx_math_dequant_evidence('vector.dequantize',context,value~canonical,value~state)
  return .MathVector~new(out,context,ev,.MathDerivation~new('vector.dequantize',.array~of(value),value~scheme))
::method dequantizeMatrix class
  use strict arg value,context
  flat=rx_math_dequantize_flat(value~payload,value~state)
  data=.array~new; k=1
  do r=1 to value~rows
    row=.array~new
    do c=1 to value~cols; row~append(rx_math_quant_to_context(flat[k],context)); k+=1; end
    data~append(row)
  end
  ev=rx_math_dequant_evidence('matrix.dequantize',context,value~canonical,value~state)
  return .MathMatrix~new(data,context,ev,.MathDerivation~new('matrix.dequantize',.array~of(value),value~scheme))

::class MathQuantizationProof public
::method prove class
  use strict arg value,claim=.nil,assumptions=.nil,policy=.nil
  if assumptions == .nil then assumptions=.MathAssumptions~new
  if claim == .nil then claim=.MathClaim~quantizationErrorBelow(value~maxErrorBound)
  if claim~kind<>'QUANTIZATION_ERROR_BELOW' then return .MathProof~new('UNSUPPORTED_CLAIM',value~evidence,.nil,.directory~new,.array~of('Quantized values currently certify QUANTIZATION_ERROR_BELOW claims only.'),claim,assumptions,'INDETERMINATE')
  tol=.MathRational~coerce(claim~parameter,.MathContext~rational)
  actual=value~maxAbsError
  checks=.directory~new
  checks['actualMaxAbsError']=actual~string; checks['tolerance']=tol~string
  checks['scope']='retained represented source values under declared quantization scheme/state'; checks['scheme']=value~scheme~canonical
  if actual~compareTo(tol)<=0 then do
    outcome='PROVED'; status='EXACT_BOUND_CERTIFIED'
    notes=.array~of('Quantization reconstruction error was replayed using exact rational arithmetic over the represented source values and retained quantization state.','This does not recover information lost before the source values entered Maths and does not certify model-level task quality.')
  end
  else do
    outcome='DISPROVED'; status='BOUND_EXCEEDED'; notes=.array~of('The exact replayed maximum reconstruction error exceeds the requested tolerance over the retained represented source values.')
  end
  return .MathProof~new(status,value~evidence,.nil,checks,notes,claim,assumptions,outcome)

::routine rx_math_quant_exact public
  use strict arg value
  if value~isA(.MathRational) then return value
  return .MathRational~coerce(value,.MathContext~rational)

::routine rx_math_quant_round_nearest_even public
  use strict arg value
  r=.MathRational~coerce(value,.MathContext~rational)
  n=r~numerator; d=r~denominator
  work=rx_math_integer_work_digits(n,d)+12; if work<50 then work=50
  numeric digits work
  sign=1; if n<0 then do; sign=-1; n=0-n; end
  q=n%d; rem=n//d; twice=rem*2
  if twice>d then q+=1
  else if twice=d then if q//2<>0 then q+=1
  if sign<0 then q=0-q
  return q

::routine rx_math_quantize_flat public
  use strict arg source,scheme
  payload=.array~new; scales=.array~new
  maxError=.MathRational~of(0,1,.MathContext~rational); maxBound=.MathRational~of(0,1,.MathContext~rational)
  bs=scheme~blockSize; count=source~items; start=1
  do while start<=count
    finish=start+bs-1; if finish>count then finish=count
    absmax=.MathRational~of(0,1,.MathContext~rational)
    do i=start to finish
      av=source[i]~abs; if av~compareTo(absmax)>0 then absmax=av
    end
    if scheme~name='SYMMETRIC_INT8' then do
      if absmax~numerator=0 then do; scale=.MathRational~of(1,1,.MathContext~rational); blockBound=.MathRational~of(0,1,.MathContext~rational); end
      else do; scale=absmax/127; blockBound=scale/2; end
      scales~append(scale); if blockBound~compareTo(maxBound)>0 then maxBound=blockBound
      do i=start to finish
        if absmax~numerator=0 then q=0; else q=rx_math_quant_round_nearest_even(source[i]/scale)
        if q>127 then q=127; if q< -127 then q=-127
        payload~append(q)
        recon=.MathRational~of(q,1,.MathContext~rational)*scale
        err=(source[i]-recon)~abs; if err~compareTo(maxError)>0 then maxError=err
      end
    end
    else if scheme~name='NF4' then do
      if absmax~numerator=0 then scale=.MathRational~of(1,1,.MathContext~rational); else scale=absmax
      scales~append(scale); cb=scheme~codebook; blockGap=.MathRational~of(0,1,.MathContext~rational)
      do j=1 to cb~size-1
        gap=(cb~at(j+1)-cb~at(j))~abs/2; if gap~compareTo(blockGap)>0 then blockGap=gap
      end
      if absmax~numerator=0 then blockBound=.MathRational~of(0,1,.MathContext~rational); else blockBound=blockGap*scale
      if blockBound~compareTo(maxBound)>0 then maxBound=blockBound
      do i=start to finish
        if absmax~numerator=0 then normalized=.MathRational~of(0,1,.MathContext~rational); else normalized=source[i]/scale
        idx=cb~nearestIndex(normalized); payload~append(idx-1); recon=cb~at(idx)*scale
        err=(source[i]-recon)~abs; if err~compareTo(maxError)>0 then maxError=err
      end
    end
    else raise syntax 88.900 array('PURE quantizer supporting SYMMETRIC_INT8 or NF4',scheme~name)
    start=finish+1
  end
  qres=.directory~new
  qres['payload']=payload; qres['scales']=scales; qres['maxError']=maxError; qres['maxBound']=maxBound
  if scheme~name='SYMMETRIC_INT8' then qres['details']='Exact rational block absmax/127 scaling; signed payload [-127,127]; nearest-even code selection.'
  else qres['details']='Exact rational replay using declared 16-value NF4 decimal codebook and per-block absmax scaling; payload is unpacked code indices 0..15.'
  return qres

::routine rx_math_dequantize_flat public
  use strict arg payload,state
  scheme=state~scheme; scales=state~scales; bs=scheme~blockSize; out=.array~new; count=payload~items
  do i=1 to count
    block=((i-1)%bs)+1; scale=scales[block]
    if scheme~name='SYMMETRIC_INT8' then recon=.MathRational~of(payload[i],1,.MathContext~rational)*scale
    else if scheme~name='NF4' then recon=scheme~codebook~at(payload[i]+1)*scale
    else raise syntax 88.900 array('known quantized scheme for dequantization',scheme~name)
    out~append(recon)
  end
  return out

::routine rx_math_quant_to_context public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then return value
  return value~toDecimal(context~workingDigits)

::routine rx_math_quant_payload_string public
  use strict arg payload
  s='['; first=.true
  do q over payload; if \first then s=s','; first=.false; s=s||q; end
  return s']'

::routine rx_math_quant_evidence public
  use strict arg operation,context,sourceCanonical,scheme,state,qres
  ev=.MathEvidence~new(operation,context,.array~of(sourceCanonical))
  guarantee='LOSSY_EXACTLY_CHARACTERIZED_OVER_REPRESENTED_VALUES'
  if scheme~name='NF4' then guarantee='LOSSY_EXACTLY_CHARACTERIZED_AGAINST_DECLARED_NF4_CODEBOOK'
  rep=scheme~storageType~name' payload + exact rational block scales + retained scheme/state'
  tags='PURE,QUANTIZATION,'||scheme~name||',BLOCKWISE'
  ev~addStep(.MathPathStep~new(operation,'PURE','0.7','exact-rational-blockwise-'scheme~name,'QUANTIZED','dynamic-integer',rep,qres['details'],guarantee,tags))
  ev~putCheck('scheme',scheme~canonical); ev~putCheck('maxAbsError',qres['maxError']~string); ev~putCheck('maxErrorBound',qres['maxBound']~string)
  ev~putCheck('errorScope','retained represented source values'); ev~putCheck('state',state~canonical)
  ev~addWarning('Quantization is intentionally lossy. Exact certification applies to reconstruction error relative to values represented when they entered Maths, not to an unknown pre-existing real-world value.')
  if scheme~name='NF4' then ev~addWarning('NF4 reference quantization uses the declared bitsandbytes 16-value decimal codebook. It does not claim byte-for-byte compatibility with a particular packed GPU kernel or compressed-statistics implementation.')
  return ev

::routine rx_math_dequant_evidence public
  use strict arg operation,context,sourceCanonical,state
  ev=.MathEvidence~new(operation,context,.array~of(sourceCanonical)); tags='PURE,DEQUANTIZATION,'||state~scheme~name
  ev~addStep(.MathPathStep~new(operation,'PURE','0.7','stateful-dequantization',context~numberDomain,context~workingDigits,rx_math_representation(context),'Reconstructs values from quantized payload and retained block scales/codebook.','APPROXIMATE_RECONSTRUCTION_OF_QUANTIZED_REPRESENTATION',tags))
  ev~putCheck('quantizationState',state~canonical); ev~putCheck('sourceMaxAbsError',state~maxAbsError~string)
  return ev


/* Conservative dotted-numeric version comparison for provider capability gates. */
::routine rx_math_version_at_least public
  use strict arg actual, required
  parse var actual a1 '.' a2 '.' a3 .
  parse var required r1 '.' r2 '.' r3 .
  if datatype(a1,'W')=0 then return 0
  if datatype(a2,'W')=0 then a2=0
  if datatype(a3,'W')=0 then a3=0
  if datatype(r1,'W')=0 then return 0
  if datatype(r2,'W')=0 then r2=0
  if datatype(r3,'W')=0 then r3=0
  if a1>r1 then return 1
  if a1<r1 then return 0
  if a2>r2 then return 1
  if a2<r2 then return 0
  return a3>=r3
