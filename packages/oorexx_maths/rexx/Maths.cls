/* oorexx_maths v0.17
 * Provider-neutral mathematical objects with explicit precision, evidence,
 * derivation and independent recomputation support.
 */

if \.local~hasIndex('OOREXX_MATHS_PROVIDERS') then .local['OOREXX_MATHS_PROVIDERS'] = .directory~new
if \.local~hasIndex('OOREXX_MATHS_CONSTANT_CACHE') then .local['OOREXX_MATHS_CONSTANT_CACHE'] = .directory~new

::class Maths public
::method version class
  return '0.17'

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
      candidates=.array~new
      if operation<>'' then do
        if operation~left(9)='dynamics.' then do
          candidates~append('SCIPY'); candidates~append('NUMPY'); candidates~append('RXMATH')
        end
        else if operation~left(7)='scalar.' then do
          candidates~append('RXMATH'); candidates~append('NUMPY')
        end
        else do
          candidates~append('NUMPY'); candidates~append('RXMATH')
        end
      end
      else do
        candidates~append('NUMPY'); candidates~append('RXMATH')
      end
      do name over candidates
        p=self~provider(name)
        if p \== .nil then do
          if operation='' then return p
          if p~supports(operation) then return p
        end
      end
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


::method angleDegrees class
  use strict arg value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathAngle~degrees(value,context)

::method angleRadians class
  use strict arg value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathAngle~radians(value,context)

::method vector3 class
  use strict arg x=0,y=0,z=0,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathVector3~new(x,y,z,context)

::method vector4 class
  use strict arg x=0,y=0,z=0,w=0,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathVector4~new(x,y,z,w,context)

::method quaternion class
  use strict arg w=1,x=0,y=0,z=0,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathQuaternion~new(w,x,y,z,context)

::method transform3D class
  use strict arg matrix=.nil,context=.nil,convention=.nil
  if context == .nil then context=self~defaultContext
  return .MathTransform3D~new(matrix,context,convention)

::method perspective class
  use strict arg fovY,aspect,near,far,context=.nil,convention=.nil
  if context == .nil then context=self~defaultContext
  return .MathPerspective~new(fovY,aspect,near,far,context,convention)

::method orthographic class
  use strict arg left,right,bottom,top,near,far,context=.nil,convention=.nil
  if context == .nil then context=self~defaultContext
  return .MathOrthographic~new(left,right,bottom,top,near,far,context,convention)



::method namedConstant class
  use strict arg name, context=.nil
  if context == .nil then context=self~defaultContext
  return rx_math_named_constant(name,context)

::method constantNames class
  return rx_math_constant_names()

::method constantInfo class
  use strict arg name
  return rx_math_constant_info(name)

::method hasNamedConstant class
  use strict arg name
  return rx_math_resolve_constant_name(name) <> ''

::method pi class
  use strict arg context=.nil
  if context == .nil then context=self~defaultContext
  return self~namedConstant('PI',context)

::method sqrt class
  use strict arg value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathScalarResult~compute('SQRT',value,context)~value

::method sin class
  use strict arg value, context=.nil
  if value~isA(.MathAngle) then return value~sin
  if context == .nil then context=self~defaultContext
  return .MathScalarResult~compute('SIN',value,context)~value

::method cos class
  use strict arg value, context=.nil
  if value~isA(.MathAngle) then return value~cos
  if context == .nil then context=self~defaultContext
  return .MathScalarResult~compute('COS',value,context)~value

::method tan class
  use strict arg value, context=.nil
  if value~isA(.MathAngle) then return value~tan
  if context == .nil then context=self~defaultContext
  return .MathScalarResult~compute('TAN',value,context)~value

::method exp class
  use strict arg value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathScalarResult~compute('EXP',value,context)~value

::method ln class
  use strict arg value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathScalarResult~compute('LN',value,context)~value

::method log10 class
  use strict arg value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathScalarResult~compute('LOG10',value,context)~value

::method atan class
  use strict arg value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathAngle~radians(.MathScalarResult~compute('ATAN',value,context)~value,context)

::method atan2 class
  use strict arg y,x,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathAngle~radians(.MathScalarResult~compute('ATAN2',.array~of(y,x),context)~value,context)

::method scalarResult class
  use strict arg operation, value, context=.nil
  if context == .nil then context=self~defaultContext
  return .MathScalarResult~compute(operation,value,context)

::method linearInterpolator class
  use strict arg coordinates,values,context=.nil,boundaryPolicy='FAIL'
  if context == .nil then context=self~defaultContext
  return .MathLinearInterpolator1D~new(coordinates,values,context,boundaryPolicy)

::method bilinearInterpolator class
  use strict arg xCoordinates,yCoordinates,valueRows,context=.nil,boundaryPolicy='FAIL'
  if context == .nil then context=self~defaultContext
  return .MathBilinearInterpolator2D~new(xCoordinates,yCoordinates,valueRows,context,boundaryPolicy)

::method sampledSeries class
  use strict arg context=.nil
  if context == .nil then context=self~defaultContext
  return .MathSampledScalarSeries~new(context)

::method quadratic class
  use strict arg a,b,c,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathQuadraticEquation~new(a,b,c,context)

::method linearSystem class
  use strict arg coefficients,rhs,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathLinearSystem~new(coefficients,rhs,context)

::method secondOrderLinearSystem class
  use strict arg massMatrix,dampingMatrix,stiffnessMatrix,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathSecondOrderLinearSystem~new(massMatrix,dampingMatrix,stiffnessMatrix,context)

::method secondOrderSystem class
  use strict arg massMatrix,dampingMatrix,stiffnessMatrix,context=.nil
  return self~secondOrderLinearSystem(massMatrix,dampingMatrix,stiffnessMatrix,context)

::method sampleDelayLine class
  use strict arg delaySamples,initialValue=0,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathSampleDelayLine~new(delaySamples,initialValue,context)

::method secondOrderContinuation class
  use strict arg system,initialDisplacement,initialVelocity,startTime=0,method='SYMPLECTIC_EULER'
  return .MathSecondOrderContinuation~new(system,initialDisplacement,initialVelocity,startTime,method)

::method secondOrderInputOutputSystem class
  use strict arg system,inputMatrix,displacementOutputMatrix,velocityOutputMatrix,context=.nil
  if context == .nil then context=system~context
  return .MathSecondOrderInputOutputSystem~new(system,inputMatrix,displacementOutputMatrix,velocityOutputMatrix,context)

::method discreteStateSpace class
  use strict arg stateMatrix,inputMatrix,outputMatrix,feedthroughMatrix,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathDiscreteStateSpaceSystem~new(stateMatrix,inputMatrix,outputMatrix,feedthroughMatrix,context)

::method discreteStateContinuation class
  use strict arg system,initialState=.nil
  return .MathDiscreteStateContinuation~new(system,initialState)


::method convolve class
  use strict arg left,right,context=.nil
  if context == .nil then context=self~defaultContext
  if \left~isA(.MathVector) then left=.MathVector~new(left,context)
  if \right~isA(.MathVector) then right=.MathVector~new(right,context)
  return .Maths~providerFor(context,'signal.convolve')~signalConvolve(left,right,context)

::method oscillatorBank class
  use strict arg amplitudes,frequenciesHz,decayPerSecond,phaseRadians=.nil,sampleRate=48000,context=.nil
  if context == .nil then context=self~defaultContext
  return .MathDampedOscillatorBank~new(amplitudes,frequenciesHz,decayPerSecond,phaseRadians,sampleRate,context)

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
    ev~addStep(.MathPathStep~new('rational.construct','PURE','0.12','integer-gcd-normalization','EXACT_RATIONAL','exact','normalized numerator/denominator','no floating-point conversion','EXACT','PURE,RATIONAL,INTEGER-GCD'))
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
  scale=frac~length-exponent
  work=digits~length+scale~abs+12
  if work<32 then work=32
  numeric digits work
  if sign<0 then n='-'||digits; else n=digits
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
  if nonrep='' then a=0; else a=nonrep
  b=repeat
  base=10**m
  cycle=(10**n)-1
  den=base*cycle
  num=whole*den + a*cycle + b
  if sign<0 then num=0-num
  out=.MathRational~of(num,den,context)
  ev=.MathEvidence~new('rational.parseRepeatingDecimal',context,.array~of(text~string))
  ev~addStep(.MathPathStep~new('rational.parseRepeatingDecimal','PURE','0.12','exact-geometric-series-decimal-conversion','EXACT_RATIONAL','exact','repeating decimal converted algebraically to rational','no floating-point conversion; denominator=10^m*(10^n-1)','EXACT','PURE,RATIONAL,REPEATING-DECIMAL'))
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
  ev~addStep(.MathPathStep~new('rational.decimalExpansion','PURE','0.12','exact-long-division-cycle-detection','BASE10_EXACT_EXPANSION','exact','finite or recurring base-10 expansion derived by exact integer long division','remainders are retained exactly; recurring cycle begins when a remainder repeats','EXACT','PURE,RATIONAL,LONG-DIVISION,CYCLE-DETECTION'))
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
  ev~addStep(.MathPathStep~new(operation,'PURE','0.12','exact-integer-rational-arithmetic','EXACT_RATIONAL','exact','normalized numerator/denominator','unreduced='unred'; canonical='canonical'; integer arithmetic followed by exact gcd normalization','EXACT','PURE,RATIONAL,INTEGER-GCD'))
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
::method evaluate; expose _text; return _text
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
  if _op='SUB' then if l~canonical=r~canonical then return .MathConstant~new(0,self~context,.true)
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
  _real=real; _imaginary=imaginary
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
  expose _data _backendProvider _backendValue
  use strict arg data, context=.nil, evidence=.nil, derivation=.nil, backendProvider='', backendValue=.nil
  if context == .nil then context=.Maths~defaultContext
  self~init:super(context,evidence,derivation)
  if \data~isA(.array) then raise syntax 88.900 array('Array',data~class~id)
  _data=.array~new
  numeric digits context~workingDigits
  do v over data; _data~append(rx_math_coerce_value(v,context)); end
  _backendProvider=backendProvider~upper; _backendValue=backendValue
::method size; expose _data; return _data~items
::method items; expose _data; return _data~items
::method at; expose _data; use strict arg i; return _data[i]
::method '[]'; expose _data; use strict arg i; return _data[i]
::method toArray
  expose _data
  out=.array~new; do v over _data; out~append(v); end; return out
::method backendProvider; expose _backendProvider; return _backendProvider
::method backendValue; expose _backendValue; return _backendValue
::method _attachBackend
  expose _backendProvider _backendValue
  use strict arg provider,value
  _backendProvider=provider~upper; _backendValue=value; return self
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
::method convolve
  use strict arg other
  if \other~isA(.MathVector) then other=.MathVector~new(other,self~context)
  return .Maths~providerFor(self~context,'signal.convolve')~signalConvolve(self,other,self~context)
::method quantize
  use strict arg scheme=.nil
  if scheme == .nil then scheme=.MathQuantizationScheme~int8
  return .MathQuantizer~quantize(self,scheme)
::method string
  expose _data
  s='['; first=.true
  do v over _data; if \first then s=s', '; first=.false; s=s||v; end
  return s']'
::method uninit
  expose _backendValue
  if symbol('_backendValue')='VAR' then if _backendValue \== .nil then do
    if _backendValue~hasMethod('CLOSE') then _backendValue~close
  end


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
    ev~addStep(.MathPathStep~new('matrix.construct','PURE','0.12','canonical-copy',context~numberDomain,context~workingDigits,rx_math_representation(context),'rectangular validation'))
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
  if \b~isA(.MathVector) then if \b~isA(.MathMatrix) then b=.MathVector~new(b,self~context)
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
::method version; return '0.17'
::method supports
  use strict arg operation
  return .false
::method scalarCompute
  use strict arg operation,value,context
  raise syntax 88.900 array('provider scalar operation',self~name operation)

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
::method scalarCompute
  use strict arg operation,value,context
  answer=rx_math_scalar_kernel(operation,value,context)
  guarantee='APPROXIMATE_HIGH_PRECISION'; if answer~isA(.MathExactNumber) then guarantee='EXACT'
  op=operation~upper; low=op~lower
  inputs=.array~new
  if value~isA(.array) then do v over value; inputs~append(v); end; else inputs~append(value)
  ev=.MathEvidence~new('scalar.'low,context,inputs)
  ignored=ev~addStep(.MathPathStep~new('scalar.'low,self~name,self~version,'maths-high-precision-scalar',context~numberDomain,context~workingDigits,'ooRexx Maths scalar kernel','Explicit context precision; no native binary64 narrowing.',guarantee,'PURE,SCALAR,'op))
  deriv=.MathDerivation~new('scalar.'low,inputs)
  return .MathScalarResult~new(answer,op,context,ev,deriv)
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



::method seriesMean
  use strict arg series,context
  vals=series~values
  if vals~items=0 then raise syntax 93.900 array('mean requires samples')
  numeric digits context~workingDigits
  sum=rx_math_coerce_value(0,context)
  do v over vals; sum=sum+v; end
  return sum/vals~items
::method seriesRms
  use strict arg series,context
  vals=series~values
  if vals~items=0 then raise syntax 93.900 array('RMS requires samples')
  numeric digits context~workingDigits
  sum=rx_math_coerce_value(0,context)
  do v over vals; sum=sum+v*v; end
  return rx_math_numeric_sqrt(sum/vals~items,context)
::method seriesFourierComponent
  use strict arg series,frequency,context
  times=series~times; vals=series~values
  if vals~items<2 then raise syntax 93.900 array('at least two samples for Fourier projection')
  if context~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for Fourier projection',frequency)
  numeric digits context~workingDigits+20
  f=rx_math_numeric_scalar(frequency,context); n=vals~items; c=0; sn=0; pi=rx_math_numeric_pi(context)
  do i=1 to n
    a=2*pi*f*times[i]
    c=c+vals[i]*rx_math_numeric_cos(a,context)
    sn=sn+vals[i]*rx_math_numeric_sin(a,context)
  end
  cosine=2*c/n; sine=2*sn/n; amplitude=rx_math_numeric_sqrt(cosine*cosine+sine*sine,context)
  ev=.MathEvidence~new('spectrum.selected-frequency',context,.array~of(f,n))
  ev~addStep(.MathPathStep~new('spectrum.selected-frequency',self~name,self~version,'direct-fourier-projection',context~numberDomain,context~workingDigits,'MathSampledScalarSeries','Direct selected-frequency cosine/sine projection using retained sample times and Maths high-precision trigonometry.','APPROXIMATE_HIGH_PRECISION',self~name',SPECTRAL,DIRECT-FOURIER'))
  deriv=.MathDerivation~new('spectrum.selected-frequency',.array~of(series),f)
  return .MathSpectralComponent~new(f,amplitude,cosine,sine,n,context,ev,deriv)
::method seriesSpectrum
  use strict arg series,frequencies,context
  out=.array~new
  do f over frequencies; out~append(self~seriesFourierComponent(series,f,context)); end
  return out

::method seriesRfft
  use strict arg series,context
  if context~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for real FFT',context~canonical)
  if series~count<2 then raise syntax 93.900 array('at least two samples for real FFT')
  if \series~isUniform then raise syntax 88.900 array('uniformly sampled series for real FFT')
  times=series~times; vals=series~values; n=vals~items
  numeric digits context~workingDigits+20
  dt=times[2]-times[1]; if dt<=0 then raise syntax 88.900 array('positive sample interval for real FFT',dt)
  t0=times[1]; bins=.array~new; pi=rx_math_numeric_pi(context)
  last=n%2
  do k=0 to last
    re=0; im=0; f=k/(n*dt)
    do i=1 to n
      rel=times[i]-t0; angle=2*pi*f*rel
      re=re+vals[i]*rx_math_numeric_cos(angle,context)
      im=im-vals[i]*rx_math_numeric_sin(angle,context)
    end
    bins~append(.MathFFTBin~new(k,f,re,im,n,context))
  end
  ev=.MathEvidence~new('spectrum.rfft',context,.array~of(n,dt,t0))
  ev~addStep(.MathPathStep~new('spectrum.rfft',self~name,self~version,'direct-half-dft',context~numberDomain,context~workingDigits,'MathFFTResult','Independent O(N^2) real-input half-spectrum DFT relative to the first retained sample time.','APPROXIMATE_HIGH_PRECISION',self~name',SPECTRAL,DIRECT-DFT'))
  deriv=.MathDerivation~new('spectrum.rfft',.array~of(series))
  return .MathFFTResult~new(bins,1/dt,n,t0,context,ev,deriv)

::method signalConvolve
  use strict arg left,right,context
  numeric digits context~workingDigits
  n=left~size; m=right~size
  if n=0 | m=0 then raise syntax 93.900 array('non-empty vectors for convolution')
  out=.array~new(n+m-1)
  do i=1 to n+m-1; out[i]=rx_math_zero(context); end
  do i=1 to n
    do j=1 to m
      out[i+j-1]=out[i+j-1]+left[i]*right[j]
    end
  end
  ev=self~_matrixEvidence('signal.convolve',context,.array~of(left~canonical,right~canonical),'direct-linear-convolution','full discrete linear convolution')
  return .MathVector~new(out,context,ev,.MathDerivation~new('signal.convolve',.array~of(left,right)))

::method oscillatorBankRender
  use strict arg bank,sampleCount,startSample,context
  if context~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for damped oscillator rendering',context~canonical)
  if \datatype(sampleCount,'W') | sampleCount<1 then raise syntax 88.900 array('positive oscillator sample count',sampleCount)
  if \datatype(startSample,'W') | startSample<0 then raise syntax 88.900 array('non-negative oscillator start sample',startSample)
  numeric digits context~workingDigits+20
  amps=bank~amplitudes; freqs=bank~frequenciesHz; decays=bank~decayPerSecond; phases=bank~phaseRadians
  sr=bank~sampleRate; pi=rx_math_numeric_pi(context); out=.array~new
  do j=0 to sampleCount-1
    t=(startSample+j)/sr; y=0
    do i=1 to amps~items
      angle=2*pi*freqs[i]*t+phases[i]
      y=y+amps[i]*rx_math_numeric_exp(-decays[i]*t,context)*rx_math_numeric_sin(angle,context)
    end
    out~append(y)
  end
  ev=self~_matrixEvidence('signal.oscillator-bank',context,.array~of(bank~canonical,sampleCount,startSample),'direct-damped-sinusoid-sum','one high-precision scalar recurrence evaluation per mode/sample')
  return .MathVector~new(out,context,ev,.MathDerivation~new('signal.oscillator-bank',.array~of(bank,sampleCount,startSample)))

::method secondOrderIntegrate
  use strict arg system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context
  return rx_math_second_order_integrate(self,system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context,self~name)
::method secondOrderIntegrateFinal
  use strict arg system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context
  trajectory=rx_math_second_order_integrate(self,system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context,self~name)
  state=trajectory~finalState
  deriv=.MathDerivation~new('dynamics.second-order.final',.array~of(system,initialDisplacement,initialVelocity,dt,steps,forces,startTime),method)
  return .MathSecondOrderState~new(state~time,state~displacement,state~velocity,state~acceleration,context,trajectory~evidence,deriv)

::method secondOrderIntegrateProjected
  use strict arg io,initialDisplacement,initialVelocity,dt,steps,inputs,startTime,method,context
  numeric digits context~workingDigits+16
  n=io~system~dimension; m=io~inputCount
  if inputs==.nil then do
    U=.array~new; do k=1 to steps+1; row=.array~new; do j=1 to m; row~append(0); end; U~append(row); end
  end
  else if inputs~isA(.MathMatrix) then U=inputs~toArray
  else do
    if m=1 then do
      if inputs~isA(.MathVector) then do; raw=inputs~toArray; U=.array~new; do z over raw; U~append(.array~of(z)); end; end
      else U=inputs
    end
    else U=inputs
  end
  if U~items<>steps+1 then raise syntax 88.900 array('input history with steps+1 rows',steps+1,U~items)
  B=io~inputMatrix; F=.array~new
  do k=1 to steps+1
    if U[k]~items<>m then raise syntax 88.900 array('input history row matching input count',m,U[k]~items)
    fr=.array~new
    do i=1 to n
      y=0; do j=1 to m; y+=B[i,j]*U[k][j]; end; fr~append(y)
    end
    F~append(fr)
  end
  tr=io~system~integrate(initialDisplacement,initialVelocity,dt,steps,F,startTime,method)
  Hx=io~displacementOutputMatrix; Hv=io~velocityOutputMatrix; ys=.array~new
  do k=1 to tr~stepCount+1
    st=tr~state(k-1); x=st~displacement; v=st~velocity; row=.array~new
    do r=1 to io~outputCount
      y=0; do i=1 to n; y+=Hx[r,i]*x[i]+Hv[r,i]*v[i]; end; row~append(y)
    end
    ys~append(row)
  end
  ev=.MathEvidence~new('dynamics.second-order.io',context,.array~of(io~canonical,'dt='dt,'steps='steps,'t0='startTime))
  ev~addStep(.MathPathStep~new('dynamics.second-order.io',self~name,self~version,'second-order + explicit B/H projection',context~numberDomain,context~workingDigits,'MathSecondOrderProjectedTrajectory','Force and selected output projection around the existing second-order integrator.','APPROXIMATE_HIGH_PRECISION',self~name',SECOND-ORDER,INPUT-OUTPUT,PROJECTION'))
  return .MathSecondOrderProjectedTrajectory~new(tr~times,ys,tr~finalState,dt,startTime,context,ev,.MathDerivation~new('dynamics.second-order.io',.array~of(io,initialDisplacement,initialVelocity,dt,steps,inputs,startTime),method))

::method discreteStateSpaceProcess
  use strict arg system,initialState,inputs,context
  numeric digits context~workingDigits+12
  n=system~stateCount; m=system~inputCount; q=system~outputCount
  if initialState~isA(.MathVector) then x=initialState~toArray; else x=initialState~copy
  if x~items<>n then raise syntax 88.900 array('discrete state vector matching state count',n,x~items)
  if inputs~isA(.MathMatrix) then U=inputs~toArray; else U=inputs
  if U~items<1 then raise syntax 88.900 array('at least one discrete input sample')
  A=system~stateMatrix~toArray; B=system~inputMatrix~toArray; C=system~outputMatrix~toArray; D=system~feedthroughMatrix~toArray
  ys=.array~new
  do k=1 to U~items
    if U[k]~items<>m then raise syntax 88.900 array('discrete input row matching input count',m,U[k]~items)
    row=.array~new
    do r=1 to q
      y=rx_math_zero(context)
      do i=1 to n; y=y+C[r][i]*x[i]; end
      do j=1 to m; y=y+D[r][j]*U[k][j]; end
      row~append(y)
    end
    ys~append(row)
    nx=.array~new
    do i=1 to n
      v=rx_math_zero(context)
      do j=1 to n; v=v+A[i][j]*x[j]; end
      do j=1 to m; v=v+B[i][j]*U[k][j]; end
      nx~append(v)
    end
    x=nx
  end
  ev=self~_matrixEvidence('signal.state-space',context,.array~of(system~canonical,'samples='U~items),'direct-discrete-state-recurrence','y[k]=C*x[k]+D*u[k]; x[k+1]=A*x[k]+B*u[k]')
  return .MathDiscreteStateSpaceTrajectory~new(ys,.MathVector~new(x,context,ev),U~items,context,ev,.MathDerivation~new('signal.state-space',.array~of(system,initialState,inputs)))

::class MathReferenceProvider subclass MathProvider public
::method name; return 'REFERENCE'
::method supports; use strict arg operation; return .true
::method scalarCompute
  use strict arg operation,value,context
  answer=rx_math_scalar_kernel(operation,value,context)
  op=operation~upper; low=op~lower
  inputs=.array~new
  if value~isA(.array) then do v over value; inputs~append(v); end; else inputs~append(value)
  ev=.MathEvidence~new('scalar.'low,context,inputs)
  ignored=ev~addStep(.MathPathStep~new('scalar.'low,self~name,self~version,'reference-high-precision-scalar',context~numberDomain,context~workingDigits,'ooRexx independent scalar replay','Recomputed at verification precision through the reference provider.','APPROXIMATE_HIGH_PRECISION','REFERENCE,SCALAR,'op))
  deriv=.MathDerivation~new('scalar.'low,inputs)
  return .MathScalarResult~new(answer,op,context,ev,deriv)
::method seriesMean
  use strict arg series,context
  return .Maths~provider('PURE')~seriesMean(series,context)
::method seriesRms
  use strict arg series,context
  return .Maths~provider('PURE')~seriesRms(series,context)
::method seriesFourierComponent
  use strict arg series,frequency,context
  pure=.Maths~provider('PURE')~seriesFourierComponent(series,frequency,context)
  ev=.MathEvidence~new('spectrum.selected-frequency',context,.array~of(frequency,series~count))
  ev~addStep(.MathPathStep~new('spectrum.selected-frequency',self~name,self~version,'reference-direct-fourier-projection',context~numberDomain,context~workingDigits,'MathSampledScalarSeries','Independent replay at verification precision.','APPROXIMATE_HIGH_PRECISION','REFERENCE,SPECTRAL,DIRECT-FOURIER'))
  deriv=.MathDerivation~new('spectrum.selected-frequency',.array~of(series),frequency)
  return .MathSpectralComponent~new(pure~frequency,pure~amplitude,pure~cosineComponent,pure~sineComponent,pure~sampleCount,context,ev,deriv)
::method seriesSpectrum
  use strict arg series,frequencies,context
  out=.array~new
  do f over frequencies; out~append(self~seriesFourierComponent(series,f,context)); end
  return out
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
  if right~isA(.MathVector) then do
    if left~cols<>right~size then raise syntax 88.900 array('compatible matrix/vector dimensions',left~cols'/'right~size)
    numeric digits context~workingDigits; out=.array~new
    do i=1 to left~rows
      products=.array~new
      do k=left~cols to 1 by -1; products~append(left[i,k]*right[k]); end
      total=rx_math_zero(context); do q over products; total=total+q; end
      out~append(total)
    end
    ev=.MathEvidence~new('matrix.matvec',context,.array~of(left~canonical,right~canonical)); ev~addStep(self~_step('matrix.matvec',context,'reverse-k-matrix-vector','independent reversed summation order'))
    return .MathVector~new(out,context,ev,.MathDerivation~new('matrix.matvec',.array~of(left,right)))
  end
  if \right~isA(.MathMatrix) then return .Maths~provider('PURE')~matrixMul(left,right,context)
  if left~cols<>right~rows then raise syntax 88.900 array('compatible matrix dimensions',left~cols'/'right~rows)
  numeric digits context~workingDigits; rows=.array~new
  do i=1 to left~rows
    row=.array~new
    do j=1 to right~cols
      products=.array~new
      do k=left~cols to 1 by -1; products~append(left[i,k]*right[k,j]); end
      total=rx_math_zero(context); do q over products; total=total+q; end
      row~append(total)
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
::method signalConvolve
  use strict arg left,right,context
  pure=.Maths~provider('PURE')~signalConvolve(left,right,context)
  ev=.MathEvidence~new('signal.convolve',context,.array~of(left~canonical,right~canonical))
  ev~addStep(self~_step('signal.convolve',context,'reference-direct-convolution','independent high-precision full linear convolution'))
  return .MathVector~new(pure~toArray,context,ev,.MathDerivation~new('signal.convolve',.array~of(left,right)))
::method oscillatorBankRender
  use strict arg bank,sampleCount,startSample,context
  pure=.Maths~provider('PURE')~oscillatorBankRender(bank,sampleCount,startSample,context)
  ev=.MathEvidence~new('signal.oscillator-bank',context,.array~of(bank~canonical,sampleCount,startSample))
  ev~addStep(self~_step('signal.oscillator-bank',context,'reference-direct-damped-sinusoid-sum','independent high-precision scalar replay'))
  return .MathVector~new(pure~toArray,context,ev,.MathDerivation~new('signal.oscillator-bank',.array~of(bank,sampleCount,startSample)))
::method seriesRfft
  use strict arg series,context
  pure=.Maths~provider('PURE')~seriesRfft(series,context)
  ev=.MathEvidence~new('spectrum.rfft',context,.array~of(series~count,pure~sampleRate,pure~timeOrigin))
  ev~addStep(self~_step('spectrum.rfft',context,'reference-direct-half-dft','independent direct DFT replay rather than FFT'))
  return .MathFFTResult~new(pure~bins,pure~sampleRate,pure~sampleCount,pure~timeOrigin,context,ev,.MathDerivation~new('spectrum.rfft',.array~of(series)))


::method secondOrderIntegrate
  use strict arg system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context
  return rx_math_second_order_integrate(self,system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context,self~name)
::method secondOrderIntegrateFinal
  use strict arg system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context
  trajectory=rx_math_second_order_integrate(self,system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context,self~name)
  state=trajectory~finalState
  deriv=.MathDerivation~new('dynamics.second-order.final',.array~of(system,initialDisplacement,initialVelocity,dt,steps,forces,startTime),method)
  return .MathSecondOrderState~new(state~time,state~displacement,state~velocity,state~acceleration,context,trajectory~evidence,deriv)

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
    outcome='DISPROVED'
    if value~numerator=expected~numerator then if value~denominator=expected~denominator then outcome='PROVED'
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
    outcome='DISPROVED'
    if value~isExact then outcome='PROVED'
    else if datatype(value~relativeAccuracyBits,'W') then do
      if value~relativeAccuracyBits>=need then outcome='PROVED'
    end
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
    v=claim~expected
    outcome='DISPROVED'
    if v>=value~lower then if v<=value~upper then outcome='PROVED'
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
  ev~addStep(.MathPathStep~new('expression.prove','PURE','0.12','structural-algebraic-rewrite-v1','SYMBOLIC','exact-where-rules-apply','ooRexx expression tree','small sound rewrite set; not a CAS','EXACT_IF_REDUCED_TO_ZERO','PURE,SYMBOLIC,STRUCTURAL'))
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
    when operation='matrix.matvec' then return provider~matrixMul(ops[1],ops[2],ctx)
    when operation='matrix.solve' then return provider~matrixSolve(ops[1],ops[2],ctx)
    when operation='vector.add' then return provider~vectorAdd(ops[1],ops[2],ctx)
    when operation='vector.sub' then return provider~vectorSub(ops[1],ops[2],ctx)
    when operation='vector.scale' then return provider~vectorMul(ops[1],deriv~parameter,ctx)
    when operation='vector.hadamard' then return provider~vectorHadamard(ops[1],ops[2],ctx)
    when operation~left(7)='scalar.' then do
      op=operation~substr(8)~upper
      if ops~items=1 then input=ops[1]; else input=ops
      return provider~scalarCompute(op,input,ctx)
    end
    when operation='spectrum.selected-frequency' then do
      source=ops[1]
      replay=.MathSampledScalarSeries~new(ctx)
      times=source~times; vals=source~values
      do i=1 to vals~items; replay~append(times[i],vals[i]); end
      return provider~seriesFourierComponent(replay,deriv~parameter,ctx)
    end
    when operation='spectrum.rfft' then do
      source=ops[1]; replay=.MathSampledScalarSeries~new(ctx)
      times=source~times; vals=source~values
      do i=1 to vals~items; replay~append(times[i],vals[i]); end
      return provider~seriesRfft(replay,ctx)
    end
    when operation='signal.convolve' then return provider~signalConvolve(ops[1],ops[2],ctx)
    when operation='signal.oscillator-bank' then return provider~oscillatorBankRender(ops[1],ops[2],ops[3],ctx)
    when operation='dynamics.second-order.integrate' then return provider~secondOrderIntegrate(ops[1],ops[2],ops[3],ops[4],ops[5],ops[6],ops[7],deriv~parameter,ctx)
    when operation='dynamics.second-order.final' then return provider~secondOrderIntegrateFinal(ops[1],ops[2],ops[3],ops[4],ops[5],ops[6],ops[7],deriv~parameter,ctx)
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
    if \plan~policy~runAll then if route~role='OBLIGATION' then if pr~outcome='PROVED' then leave
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

  if proved~items>0 then if disproved~items>0 then do
    notes~append('Proof obligations produced conflicting decisive outcomes. The planner refuses to choose a convenient answer.')
    return .MathProof~new('EVIDENCE_CONFLICT',best~proof~primaryEvidence,.nil,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
  end

  if proved~items>0 then do
    bp=best~proof
    do name over bp~checks~allIndexes; checks[name]=bp~checks[name]; end
    corroborated=rx_math_proof_corroborated(proved,supportProved,bp)
    checks['corroborated']=corroborated
    if plan~policy~certifiedOnly then if \rx_math_is_certifying_strength(bp~status) then do
      notes~append('The claim has supporting evidence, but policy CERTIFIED requires exact/symbolic/rigorous enclosure or exact-bound certification.')
      return .MathProof~new('INSUFFICIENT_CERTIFICATION',bp~primaryEvidence,bp~verificationEvidence,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
    end
    if plan~policy~requireCorroboration then do
      supportPlanned=0
      do r over plan~routes; if r~role='SUPPORT' then supportPlanned+=1; end
      checks['supportPlanned']=supportPlanned
      if supportPlanned>0 then if supportProved~items=0 then do
        notes~append('Policy STRONG requested an independent supporting route and it did not succeed. This does not disprove the stated obligation; it prevents the stronger policy from declaring the evidence sufficient.')
        return .MathProof~new('CORROBORATION_REQUIRED',bp~primaryEvidence,bp~verificationEvidence,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
      end
      if supportPlanned=0 then if plan~routeCount>1 then if \corroborated then do
        notes~append('Policy STRONG planned materially different corroboration, but that corroboration did not succeed. The proved obligation remains evidence, but the strong-policy result is INDETERMINATE.')
        return .MathProof~new('CORROBORATION_REQUIRED',bp~primaryEvidence,bp~verificationEvidence,checks,notes,plan~claim,plan~assumptions,'INDETERMINATE',plan,attempts)
      end
    end
    do n over bp~notes; notes~append(n); end
    verification=bp~verificationEvidence
    if verification == .nil then if supportProved~items>0 then do
      verification=supportProved[1]~proof~verificationEvidence
      if verification == .nil then verification=supportProved[1]~proof~primaryEvidence
    end
    if verification == .nil then if proved~items>1 then do
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
  if alternate == .nil then return .MathProof~new('UNVERIFIED',value~evidence,.nil,.directory~new,.array~of('No independent recomputation path is registered for this derivation in v0.12.'),claim,assumptions,'INDETERMINATE')
  checks=.directory~new; notes=.array~new
  if value~isA(.MathMatrix) then diff=value~maxAbsDifference(alternate)
  else if value~isA(.MathVector) then diff=rx_math_vector_max_abs_difference(value,alternate)
  else if value~isA(.MathScalarResult) then diff=(value~value-alternate~value)~abs
  else if value~isA(.MathSpectralComponent) then do
    d1=(value~amplitude-alternate~amplitude)~abs
    d2=(value~cosineComponent-alternate~cosineComponent)~abs
    d3=(value~sineComponent-alternate~sineComponent)~abs
    diff=max(d1,max(d2,d3))
  end
  else if value~isA(.MathFFTResult) then diff=value~maxAbsDifference(alternate)
  else if value~isA(.MathSecondOrderTrajectory) then diff=value~maxAbsDifference(alternate)
  else if value~isA(.MathSecondOrderState) then diff=value~maxAbsDifference(alternate)
  else diff='INF'
  checks['maxAbsDifference']=diff
  if value~evidence~steps~items>0 then if alternate~evidence~steps~items>0 then do
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
  if value~context~numberDomain='RATIONAL' then notes~append('Independent recomputation used provider 'checks['verificationProvider']' through a distinct exact path in the same exact rational domain.')
  else do
    verificationProvider=checks['verificationProvider']
    if verificationProvider == .nil then verificationProvider='UNKNOWN'
    notes~append('Independent recomputation used verification provider 'verificationProvider' at increased decimal precision.')
  end
  notes~append('The outcome applies only to the stated INDEPENDENT_REPRODUCTION claim and declared tolerance; it is not a theorem that the numerical value is exact.')
  return .MathProof~new(status,value~evidence,alternate~evidence,checks,notes,claim,assumptions,outcome)

::method _proveEquation class
  use strict arg value,claim,assumptions
  checks=.directory~new; notes=.array~new
  if value~derivation == .nil then do
    notes~append('SATISFIES_EQUATION is currently registered for matrix.solve derivations.')
    return .MathProof~new('UNVERIFIED',self~_baseEvidence(value,claim),.nil,checks,notes,claim,assumptions,'INDETERMINATE')
  end
  if value~derivation~operation<>'matrix.solve' then do
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
  ev~addStep(.MathPathStep~new('matrix.solve.residual','PURE','0.12','direct-equation-residual-inf-norm',ctx~numberDomain,wd,rx_math_representation(ctx),'Re-evaluates A*x-b from the retained Maths values; this evidence is separate from the path that originally produced x.',guarantee,'PURE,'ctx~numberDomain',RESIDUAL'))
  ev~putCheck('residualInf',residual); ev~putCheck('tolerance',tol)
  if value~evidence \== .nil then ev~putCheck('sourceResultProvider',value~evidence~primaryProvider)
  if rx_math_le(residual,tol,value~context) then do
    if value~context~numberDomain='RATIONAL' then if rx_math_is_zero(residual,value~context) then do
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
  ev~addStep(.MathPathStep~new('matrix.solve.residual.exact-replay','PURE','0.12','exact-rational-residual-over-represented-values','RATIONAL','dynamic-integer','normalized exact rationals','All values are reconstructed from the decimal/rational text retained by the Maths objects. This certifies the represented values; it cannot recover precision already lost before those values were retained.','EXACT_BOUND_ON_REPRESENTED_VALUES','PURE,RATIONAL,EXACT-RESIDUAL'))
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
    if a == .nil then iterate
    if a~steps~items=0 then iterate
    do j=i+1 to proved~items
      b=proved[j]~proof~primaryEvidence
      if b == .nil then iterate
      if b~steps~items=0 then iterate
      if a~steps[1]~provider<>b~steps[1]~provider then if a~steps[1]~algorithm<>b~steps[1]~algorithm then return .true
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
  return value

::routine rx_math_scalar_for_context public
  use strict arg value,context,expectation='numeric scalar'
  if context~numberDomain='RATIONAL' then return .MathRational~coerce(value,context)
  if \datatype(value,'N') then raise syntax 88.900 array(expectation,value)
  numeric digits context~workingDigits
  return value

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
  n=nt; d=dt
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
  if \values~isA(.array) then raise syntax 88.900 array('quantization codebook Array with at least two values',values)
  if values~items<2 then raise syntax 88.900 array('quantization codebook Array with at least two values',values)
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
  use strict arg scheme,shape,scales,sourceContext,provider='PURE',providerVersion='0.12',maxAbsError=.nil,maxErrorBound=.nil,sourceCanonical='',details=''
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
  if _preserveExact then if exact then return .false
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
  state=.MathQuantizationState~new(scheme,'vector:'value~size,qres['scales'],value~context,'PURE','0.12',qres['maxError'],qres['maxBound'],value~canonical,qres['details'])
  ev=rx_math_quant_evidence('vector.quantize',value~context,value~canonical,scheme,state,qres)
  return .MathQuantizedVector~new(qres['payload'],state,source,ev,.MathDerivation~new('vector.quantize',.array~of(value),scheme))
::method quantizeMatrix class
  use strict arg value,scheme
  source=.array~new
  do r=1 to value~rows
    do c=1 to value~cols; source~append(rx_math_quant_exact(value[r,c])); end
  end
  qres=rx_math_quantize_flat(source,scheme)
  state=.MathQuantizationState~new(scheme,'matrix:'value~rows'x'value~cols,qres['scales'],value~context,'PURE','0.12',qres['maxError'],qres['maxBound'],value~canonical,qres['details'])
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
  ev~addStep(.MathPathStep~new(operation,'PURE','0.12','exact-rational-blockwise-'scheme~name,'QUANTIZED','dynamic-integer',rep,qres['details'],guarantee,tags))
  ev~putCheck('scheme',scheme~canonical); ev~putCheck('maxAbsError',qres['maxError']~string); ev~putCheck('maxErrorBound',qres['maxBound']~string)
  ev~putCheck('errorScope','retained represented source values'); ev~putCheck('state',state~canonical)
  ev~addWarning('Quantization is intentionally lossy. Exact certification applies to reconstruction error relative to values represented when they entered Maths, not to an unknown pre-existing real-world value.')
  if scheme~name='NF4' then ev~addWarning('NF4 reference quantization uses the declared bitsandbytes 16-value decimal codebook. It does not claim byte-for-byte compatibility with a particular packed GPU kernel or compressed-statistics implementation.')
  return ev

::routine rx_math_dequant_evidence public
  use strict arg operation,context,sourceCanonical,state
  ev=.MathEvidence~new(operation,context,.array~of(sourceCanonical)); tags='PURE,DEQUANTIZATION,'||state~scheme~name
  ev~addStep(.MathPathStep~new(operation,'PURE','0.12','stateful-dequantization',context~numberDomain,context~workingDigits,rx_math_representation(context),'Reconstructs values from quantized payload and retained block scales/codebook.','APPROXIMATE_RECONSTRUCTION_OF_QUANTIZED_REPRESENTATION',tags))
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


/* ===== 3D MATHEMATICS v0.8 ===== */
/* ooRexx Maths v0.8 - provider-neutral 3D mathematics.
 * Column-vector semantics. Matrix storage is an implementation detail.
 * No OpenGL/Vulkan/DirectX convention is implicit: projection conventions
 * are explicit Math3DConvention values.
 */

::class MathAngle subclass MathValue public
::method init
  expose _value _unit
  use strict arg value, unit='RADIANS', context=.nil, evidence=.nil, derivation=.nil
  if context == .nil then context=.Maths~defaultContext
  self~init:super(context,evidence,derivation)
  numeric digits context~workingDigits
  _value=rx_math3d_scalar(value,context)
  _unit=unit~string~upper
  if _unit='RAD' then _unit='RADIANS'
  if _unit='DEG' then _unit='DEGREES'
  select
    when _unit='RADIANS' then nop
    when _unit='DEGREES' then nop
    otherwise raise syntax 88.900 array('RADIANS or DEGREES',unit)
  end
  if evidence == .nil then self~_setEvidence(rx_math3d_evidence('angle.construct',context,.array~of(_value,_unit),'explicit-angle-unit','Angle unit is retained; no implicit degree/radian guess.'))
::method value; expose _value; return _value
::method unit; expose _unit; return _unit
::method degrees class
  use strict arg value, context=.nil
  if context == .nil then context=.Maths~defaultContext
  return self~new(value,'DEGREES',context)
::method radians class
  use strict arg value, context=.nil
  if context == .nil then context=.Maths~defaultContext
  return self~new(value,'RADIANS',context)
::method reduced
  expose _value _unit
  ctx=self~context
  numeric digits ctx~workingDigits+20
  if _unit='DEGREES' then do
    r=rx_math3d_reduce_degrees(_value,ctx)
    return .MathAngle~new(r,'DEGREES',ctx,rx_math3d_evidence('angle.reduce',ctx,.array~of(self~canonical),'exact-degree-modulo','Reduces degrees modulo 360 into [-180,180).'))
  end
  r=rx_math3d_reduce_radians(_value,ctx)
  return .MathAngle~new(r,'RADIANS',ctx,rx_math3d_evidence('angle.reduce',ctx,.array~of(self~canonical),'high-precision-radian-modulo','Reduces radians modulo 2*pi into [-pi,pi].'))
::method radiansValue
  expose _value _unit
  ctx=self~context
  numeric digits ctx~workingDigits+30
  if ctx~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for conversion involving pi',self~canonical)
  if _unit='RADIANS' then return rx_math3d_reduce_radians(_value,ctx)
  d=rx_math3d_reduce_degrees(_value,ctx)
  return d*rx_math3d_pi(ctx)/180
::method degreesValue
  expose _value _unit
  ctx=self~context
  numeric digits ctx~workingDigits+30
  if _unit='DEGREES' then return rx_math3d_reduce_degrees(_value,ctx)
  if ctx~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for conversion involving pi',self~canonical)
  return rx_math3d_reduce_radians(_value,ctx)*180/rx_math3d_pi(ctx)
::method sin
  return .Maths~sin(self~radiansValue,self~context)
::method cos
  return .Maths~cos(self~radiansValue,self~context)
::method tan
  return .Maths~tan(self~radiansValue,self~context)
::method half
  ctx=self~context
  numeric digits ctx~workingDigits+20
  return .MathAngle~new(self~value/2,self~unit,ctx)
::method '+'
  use strict arg other
  ctx=self~context
  numeric digits ctx~workingDigits+20
  if \other~isA(.MathAngle) then raise syntax 88.900 array('MathAngle',other~class~id)
  if self~unit=other~unit then return .MathAngle~new(self~value+other~value,self~unit,ctx)
  return .MathAngle~radians(self~radiansValue+other~radiansValue,ctx)
::method '-'
  use strict arg other=.nil
  ctx=self~context
  numeric digits ctx~workingDigits+20
  if arg(1,'O') then return .MathAngle~new(-self~value,self~unit,ctx)
  if \other~isA(.MathAngle) then raise syntax 88.900 array('MathAngle',other~class~id)
  if self~unit=other~unit then return .MathAngle~new(self~value-other~value,self~unit,ctx)
  return .MathAngle~radians(self~radiansValue-other~radiansValue,ctx)
::method '*'
  use strict arg scalar
  ctx=self~context
  numeric digits ctx~workingDigits+20
  return .MathAngle~new(self~value*rx_math3d_scalar(scalar,ctx),self~unit,ctx)
::method canonical
  return 'angle['self~value';'self~unit']'
::method string
  if self~unit='DEGREES' then return self~value' deg'
  return self~value' rad'


::class MathVector3 subclass MathValue public
::method init
  expose _x _y _z
  use strict arg x=0,y=0,z=0,context=.nil,evidence=.nil,derivation=.nil
  if context == .nil then context=.Maths~defaultContext
  self~init:super(context,evidence,derivation)
  numeric digits context~workingDigits
  _x=rx_math3d_scalar(x,context); _y=rx_math3d_scalar(y,context); _z=rx_math3d_scalar(z,context)
  if evidence == .nil then self~_setEvidence(rx_math3d_evidence('vector3.construct',context,.array~of(_x,_y,_z),'component-copy','Three-dimensional vector components retained in the declared Maths context.'))
::method x; expose _x; return _x
::method y; expose _y; return _y
::method z; expose _z; return _z
::method size; return 3
::method at
  expose _x _y _z
  use strict arg i
  select; when i=1 then return _x; when i=2 then return _y; when i=3 then return _z; otherwise raise syntax 88.900 array('Vector3 index 1..3',i); end
::method '[]'; use strict arg i; return self~at(i)
::method toArray; return .array~of(self~x,self~y,self~z)
::method toVector; return .MathVector~new(self~toArray,self~context,self~evidence,self~derivation)
::method canonical; return 'vector3['self~x','self~y','self~z']'
::method string; return '['self~x', 'self~y', 'self~z']'
::method '+'
  use strict arg other
  if \other~isA(.MathVector3) then raise syntax 88.900 array('MathVector3',other~class~id)
  ctx=self~context; numeric digits ctx~workingDigits
  return .MathVector3~new(self~x+other~x,self~y+other~y,self~z+other~z,ctx,rx_math3d_evidence('vector3.add',ctx,.array~of(self~canonical,other~canonical),'component-add','Elementwise three-dimensional vector addition.'))
::method '-'
  use strict arg other=.nil
  ctx=self~context; numeric digits ctx~workingDigits
  if arg(1,'O') then return .MathVector3~new(-self~x,-self~y,-self~z,ctx)
  if \other~isA(.MathVector3) then raise syntax 88.900 array('MathVector3',other~class~id)
  return .MathVector3~new(self~x-other~x,self~y-other~y,self~z-other~z,ctx,rx_math3d_evidence('vector3.sub',ctx,.array~of(self~canonical,other~canonical),'component-subtract','Elementwise three-dimensional vector subtraction.'))
::method '*'
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  if other~isA(.MathVector3) then return self~dot(other)
  s=rx_math3d_scalar(other,ctx)
  return .MathVector3~new(self~x*s,self~y*s,self~z*s,ctx,rx_math3d_evidence('vector3.scale',ctx,.array~of(self~canonical,s),'scalar-multiply','Three-dimensional vector scaling.'))
::method dot
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  return self~x*other~x+self~y*other~y+self~z*other~z
::method cross
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  return .MathVector3~new(self~y*other~z-self~z*other~y,self~z*other~x-self~x*other~z,self~x*other~y-self~y*other~x,ctx,rx_math3d_evidence('vector3.cross',ctx,.array~of(self~canonical,other~canonical),'right-handed-cross-product','Uses the conventional right-handed algebraic cross product.'))
::method normSquared
  ctx=self~context; numeric digits ctx~workingDigits
  return self~dot(self)
::method norm
  return .Maths~sqrt(self~normSquared,self~context)
::method normalized
  ctx=self~context; numeric digits ctx~workingDigits+20
  n=self~norm
  if rx_math3d_near_zero(n,ctx) then raise syntax 88.900 array('non-zero MathVector3',self~canonical)
  return self*(1/n)
::method normalize; return self~normalized
::method maxAbsDifference
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  dx=(self~x-other~x)~abs; dy=(self~y-other~y)~abs; dz=(self~z-other~z)~abs
  return max(dx,dy,dz)


::class MathVector4 subclass MathValue public
::method init
  expose _x _y _z _w
  use strict arg x=0,y=0,z=0,w=0,context=.nil,evidence=.nil,derivation=.nil
  if context == .nil then context=.Maths~defaultContext
  self~init:super(context,evidence,derivation)
  numeric digits context~workingDigits
  _x=rx_math3d_scalar(x,context); _y=rx_math3d_scalar(y,context); _z=rx_math3d_scalar(z,context); _w=rx_math3d_scalar(w,context)
::method x; expose _x; return _x
::method y; expose _y; return _y
::method z; expose _z; return _z
::method w; expose _w; return _w
::method size; return 4
::method at
  use strict arg i
  select; when i=1 then return self~x; when i=2 then return self~y; when i=3 then return self~z; when i=4 then return self~w; otherwise raise syntax 88.900 array('Vector4 index 1..4',i); end
::method '[]'; use strict arg i; return self~at(i)
::method toArray; return .array~of(self~x,self~y,self~z,self~w)
::method toVector; return .MathVector~new(self~toArray,self~context)
::method canonical; return 'vector4['self~x','self~y','self~z','self~w']'
::method string; return '['self~x', 'self~y', 'self~z', 'self~w']'
::method '+'
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  return .MathVector4~new(self~x+other~x,self~y+other~y,self~z+other~z,self~w+other~w,ctx)
::method '-'
  use strict arg other=.nil
  ctx=self~context; numeric digits ctx~workingDigits
  if arg(1,'O') then return .MathVector4~new(-self~x,-self~y,-self~z,-self~w,ctx)
  return .MathVector4~new(self~x-other~x,self~y-other~y,self~z-other~z,self~w-other~w,ctx)
::method '*'
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  if other~isA(.MathVector4) then return self~x*other~x+self~y*other~y+self~z*other~z+self~w*other~w
  s=rx_math3d_scalar(other,ctx); return .MathVector4~new(self~x*s,self~y*s,self~z*s,self~w*s,ctx)


::class MathMatrix3 subclass MathValue public
::method init
  expose _matrix
  use strict arg matrixOrRows,context=.nil,evidence=.nil,derivation=.nil
  if matrixOrRows~isA(.MathMatrix) then do; _matrix=matrixOrRows; if context==.nil then context=_matrix~context; end
  else do; if context==.nil then context=.Maths~defaultContext; _matrix=.MathMatrix~new(matrixOrRows,context); end
  if _matrix~rows<>3 | _matrix~cols<>3 then raise syntax 88.900 array('3x3 matrix',_matrix~canonical)
  self~init:super(context,evidence,derivation)
::method matrix; expose _matrix; return _matrix
::method at; use strict arg r,c; return self~matrix[r,c]
::method '[]'; use strict arg r,c; return self~matrix[r,c]
::method canonical; return 'matrix3:'self~matrix~canonical
::method string; return self~matrix~string
::method '*'
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  if other~isA(.MathVector3) then do
    v=self~matrix*other~toVector; return .MathVector3~new(v[1],v[2],v[3],ctx)
  end
  if other~isA(.MathMatrix3) then return .MathMatrix3~new(self~matrix*other~matrix,ctx)
  return .MathMatrix3~new(self~matrix*other,ctx)
::method transpose; return .MathMatrix3~new(self~matrix~transpose,self~context)
::method identity class
  use strict arg context=.nil
  if context==.nil then context=.Maths~defaultContext
  return self~new(.MathMatrix~identity(3,context),context)


::class MathMatrix4 subclass MathValue public
::method init
  expose _matrix
  use strict arg matrixOrRows,context=.nil,evidence=.nil,derivation=.nil
  if matrixOrRows~isA(.MathMatrix) then do; _matrix=matrixOrRows; if context==.nil then context=_matrix~context; end
  else do; if context==.nil then context=.Maths~defaultContext; _matrix=.MathMatrix~new(matrixOrRows,context); end
  if _matrix~rows<>4 | _matrix~cols<>4 then raise syntax 88.900 array('4x4 matrix',_matrix~canonical)
  self~init:super(context,evidence,derivation)
::method matrix; expose _matrix; return _matrix
::method at; use strict arg r,c; return self~matrix[r,c]
::method '[]'; use strict arg r,c; return self~matrix[r,c]
::method canonical; return 'matrix4:'self~matrix~canonical
::method string; return self~matrix~string
::method toFlatArray
  use strict arg order='ROW_MAJOR'
  key=order~string~upper; out=.array~new
  if key='ROW_MAJOR' then do
    do r=1 to 4; do c=1 to 4; out~append(self[r,c]); end; end
    return out
  end
  if key='COLUMN_MAJOR' then do
    do c=1 to 4; do r=1 to 4; out~append(self[r,c]); end; end
    return out
  end
  raise syntax 88.900 array('ROW_MAJOR or COLUMN_MAJOR',order)
::method toRowMajorArray; return self~toFlatArray('ROW_MAJOR')
::method toColumnMajorArray; return self~toFlatArray('COLUMN_MAJOR')
::method '*'
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  if other~isA(.MathVector4) then do
    v=self~matrix*other~toVector; return .MathVector4~new(v[1],v[2],v[3],v[4],ctx)
  end
  if other~isA(.MathMatrix4) then return .MathMatrix4~new(self~matrix*other~matrix,ctx)
  return .MathMatrix4~new(self~matrix*other,ctx)
::method transpose; return .MathMatrix4~new(self~matrix~transpose,self~context)
::method identity class
  use strict arg context=.nil
  if context==.nil then context=.Maths~defaultContext
  return self~new(.MathMatrix~identity(4,context),context)


::class MathQuaternion subclass MathValue public
::method init
  expose _w _x _y _z
  use strict arg w=1,x=0,y=0,z=0,context=.nil,evidence=.nil,derivation=.nil
  if context==.nil then context=.Maths~defaultContext
  self~init:super(context,evidence,derivation)
  numeric digits context~workingDigits
  _w=rx_math3d_scalar(w,context); _x=rx_math3d_scalar(x,context); _y=rx_math3d_scalar(y,context); _z=rx_math3d_scalar(z,context)
  if evidence==.nil then self~_setEvidence(rx_math3d_evidence('quaternion.construct',context,.array~of(_w,_x,_y,_z),'component-copy','Quaternion stored as scalar-first (w,x,y,z).'))
::method w; expose _w; return _w
::method x; expose _x; return _x
::method y; expose _y; return _y
::method z; expose _z; return _z
::method identity class
  use strict arg context=.nil
  if context==.nil then context=.Maths~defaultContext
  return self~new(1,0,0,0,context)
::method fromAxisAngle class
  use strict arg axis,angle,context=.nil
  if context==.nil then do; if axis~isA(.MathVector3) then context=axis~context; else context=.Maths~defaultContext; end
  if \axis~isA(.MathVector3) then raise syntax 88.900 array('MathVector3 axis',axis~class~id)
  if \angle~isA(.MathAngle) then angle=.MathAngle~radians(angle,context)
  numeric digits context~workingDigits+30
  a=axis~normalized
  half=angle~radiansValue/2
  s=rx_math3d_sin(half,context); c=rx_math3d_cos(half,context)
  ev=rx_math3d_evidence('quaternion.fromAxisAngle',context,.array~of(axis~canonical,angle~canonical),'axis-angle-half-angle-trig','Normalizes the axis, evaluates sin/cos of half-angle, and constructs scalar-first quaternion.')
  return self~new(c,a~x*s,a~y*s,a~z*s,context,ev,.MathDerivation~new('quaternion.fromAxisAngle',.array~of(axis,angle)))
::method '+'
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  return .MathQuaternion~new(self~w+other~w,self~x+other~x,self~y+other~y,self~z+other~z,ctx)
::method '-'
  use strict arg other=.nil
  ctx=self~context; numeric digits ctx~workingDigits
  if arg(1,'O') then return .MathQuaternion~new(-self~w,-self~x,-self~y,-self~z,ctx)
  return .MathQuaternion~new(self~w-other~w,self~x-other~x,self~y-other~y,self~z-other~z,ctx)
::method '*'
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits+10
  if other~isA(.MathVector3) then return self~rotate(other)
  if other~isA(.MathQuaternion) then do
    w=self~w*other~w-self~x*other~x-self~y*other~y-self~z*other~z
    x=self~w*other~x+self~x*other~w+self~y*other~z-self~z*other~y
    y=self~w*other~y-self~x*other~z+self~y*other~w+self~z*other~x
    z=self~w*other~z+self~x*other~y-self~y*other~x+self~z*other~w
    return .MathQuaternion~new(w,x,y,z,ctx,rx_math3d_evidence('quaternion.multiply',ctx,.array~of(self~canonical,other~canonical),'hamilton-product','Hamilton product; order is significant.'))
  end
  s=rx_math3d_scalar(other,ctx); return .MathQuaternion~new(self~w*s,self~x*s,self~y*s,self~z*s,ctx)
::method normSquared
  ctx=self~context; numeric digits ctx~workingDigits+10
  return self~w*self~w+self~x*self~x+self~y*self~y+self~z*self~z
::method norm; return .Maths~sqrt(self~normSquared,self~context)
::method normalized
  ctx=self~context; numeric digits ctx~workingDigits+20
  n=self~norm; if rx_math3d_near_zero(n,ctx) then raise syntax 88.900 array('non-zero quaternion',self~canonical)
  return self*(1/n)
::method conjugate
  ctx=self~context; numeric digits ctx~workingDigits+20
  return .MathQuaternion~new(self~w,-self~x,-self~y,-self~z,ctx,rx_math3d_evidence('quaternion.conjugate',ctx,.array~of(self~canonical),'component-conjugation','Negates vector part under explicit working precision.'))
::method inverse
  ctx=self~context; numeric digits ctx~workingDigits+30
  n2=self~normSquared; if rx_math3d_near_zero(n2,ctx) then raise syntax 88.900 array('invertible non-zero quaternion',self~canonical)
  return self~conjugate*(1/n2)
::method rotate
  use strict arg vector
  if \vector~isA(.MathVector3) then raise syntax 88.900 array('MathVector3',vector~class~id)
  ctx=self~context; numeric digits ctx~workingDigits+30
  q=self~normalized
  p=.MathQuaternion~new(0,vector~x,vector~y,vector~z,ctx)
  r=(q*p)*q~conjugate
  return .MathVector3~new(r~x,r~y,r~z,ctx,rx_math3d_evidence('quaternion.rotateVector',ctx,.array~of(self~canonical,vector~canonical),'q-v-q-conjugate','Unit-quaternion vector rotation.'))
::method toMatrix3
  ctx=self~context; numeric digits ctx~workingDigits+30
  q=self~normalized; w=q~w; x=q~x; y=q~y; z=q~z
  xx=x*x; yy=y*y; zz=z*z; xy=x*y; xz=x*z; yz=y*z; wx=w*x; wy=w*y; wz=w*z
  rows=.array~of( -
    .array~of(1-2*(yy+zz),2*(xy-wz),2*(xz+wy)), -
    .array~of(2*(xy+wz),1-2*(xx+zz),2*(yz-wx)), -
    .array~of(2*(xz-wy),2*(yz+wx),1-2*(xx+yy)))
  return .MathMatrix3~new(rows,ctx,rx_math3d_evidence('quaternion.toMatrix3',ctx,.array~of(self~canonical),'unit-quaternion-rotation-matrix','Column-vector right-handed algebraic rotation matrix.'))
::method canonical; return 'quaternion['self~w','self~x','self~y','self~z']'
::method string; return self~canonical
::method maxAbsDifference
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits
  return max((self~w-other~w)~abs,(self~x-other~x)~abs,(self~y-other~y)~abs,(self~z-other~z)~abs)


::class Math3DConvention public
::method init
  expose _name _handedness _depthRange _vectorConvention
  use strict arg name,handedness='RIGHT_HANDED',depthRange='NEGATIVE_ONE_TO_ONE',vectorConvention='COLUMN_VECTOR'
  _name=name~string~upper; _handedness=handedness~string~upper; _depthRange=depthRange~string~upper; _vectorConvention=vectorConvention~string~upper
  select
    when _handedness='RIGHT_HANDED' then nop
    when _handedness='LEFT_HANDED' then nop
    otherwise raise syntax 88.900 array('RIGHT_HANDED or LEFT_HANDED',handedness)
  end
  select
    when _depthRange='NEGATIVE_ONE_TO_ONE' then nop
    when _depthRange='ZERO_TO_ONE' then nop
    otherwise raise syntax 88.900 array('NEGATIVE_ONE_TO_ONE or ZERO_TO_ONE',depthRange)
  end
  if _vectorConvention<>'COLUMN_VECTOR' then raise syntax 88.900 array('COLUMN_VECTOR',vectorConvention)
::method name; expose _name; return _name
::method handedness; expose _handedness; return _handedness
::method depthRange; expose _depthRange; return _depthRange
::method vectorConvention; expose _vectorConvention; return _vectorConvention
::method canonical; return self~name':'self~handedness':'self~depthRange':'self~vectorConvention
::method openGL class; return self~new('OPENGL','RIGHT_HANDED','NEGATIVE_ONE_TO_ONE','COLUMN_VECTOR')
::method vulkan class; return self~new('VULKAN','RIGHT_HANDED','ZERO_TO_ONE','COLUMN_VECTOR')
::method directX class; return self~new('DIRECTX','LEFT_HANDED','ZERO_TO_ONE','COLUMN_VECTOR')


::class MathTransform3D subclass MathValue public
::method init
  expose _matrix _convention
  use strict arg matrix=.nil,context=.nil,convention=.nil,evidence=.nil,derivation=.nil
  if context==.nil then do
    if matrix<>.nil then do
      if matrix~isA(.MathMatrix4) then context=matrix~context
      else context=.Maths~defaultContext
    end
    else context=.Maths~defaultContext
  end
  if convention==.nil then convention=.Math3DConvention~openGL
  if matrix==.nil then matrix=.MathMatrix4~identity(context)
  if \matrix~isA(.MathMatrix4) then matrix=.MathMatrix4~new(matrix,context)
  _matrix=matrix; _convention=convention
  self~init:super(context,evidence,derivation)
  if evidence==.nil then self~_setEvidence(rx_math3d_evidence('transform3d.construct',context,.array~of(matrix~canonical,convention~canonical),'explicit-4x4-transform','Column-vector transform with explicit convention metadata.'))
::method matrix; expose _matrix; return _matrix
::method convention; expose _convention; return _convention
::method identity class
  use strict arg context=.nil,convention=.nil
  if context==.nil then context=.Maths~defaultContext
  return self~new(.MathMatrix4~identity(context),context,convention)
::method translation class
  use strict arg tx,ty,tz,context=.nil,convention=.nil
  if context==.nil then context=.Maths~defaultContext
  numeric digits context~workingDigits
  rows=.array~of(.array~of(1,0,0,tx),.array~of(0,1,0,ty),.array~of(0,0,1,tz),.array~of(0,0,0,1))
  return .MathAffineTransform3D~new(.MathMatrix4~new(rows,context),context,convention,rx_math3d_evidence('transform3d.translation',context,.array~of(tx,ty,tz),'homogeneous-translation','4x4 column-vector homogeneous translation.'))
::method scale class
  use strict arg sx,sy=.nil,sz=.nil,context=.nil,convention=.nil
  if context==.nil then context=.Maths~defaultContext
  if sy==.nil then sy=sx
  if sz==.nil then sz=sx
  numeric digits context~workingDigits
  rows=.array~of(.array~of(sx,0,0,0),.array~of(0,sy,0,0),.array~of(0,0,sz,0),.array~of(0,0,0,1))
  return .MathAffineTransform3D~new(.MathMatrix4~new(rows,context),context,convention,rx_math3d_evidence('transform3d.scale',context,.array~of(sx,sy,sz),'homogeneous-scale','4x4 column-vector scale transform.'))
::method rotation class
  use strict arg quaternion,context=.nil,convention=.nil
  if context==.nil then context=quaternion~context
  m3=quaternion~toMatrix3
  rows=.array~of(.array~of(m3[1,1],m3[1,2],m3[1,3],0),.array~of(m3[2,1],m3[2,2],m3[2,3],0),.array~of(m3[3,1],m3[3,2],m3[3,3],0),.array~of(0,0,0,1))
  return .MathAffineTransform3D~new(.MathMatrix4~new(rows,context),context,convention,rx_math3d_evidence('transform3d.rotation',context,.array~of(quaternion~canonical),'quaternion-to-homogeneous-matrix','Embeds the quaternion rotation matrix in 4x4 homogeneous form.'))
::method '*'
  use strict arg other
  ctx=self~context; numeric digits ctx~workingDigits+10
  if other~isA(.MathTransform3D) then do
    m=self~matrix*other~matrix
    return .MathTransform3D~new(m,ctx,self~convention,rx_math3d_evidence('transform3d.compose',ctx,.array~of(self~canonical,other~canonical),'matrix-composition','Column-vector convention: A*B applies B first, then A.'))
  end
  if other~isA(.MathVector3) then return self~transformPoint(other)
  if other~isA(.MathVector4) then return self~matrix*other
  raise syntax 88.900 array('MathTransform3D, MathVector3 or MathVector4',other~class~id)
::method transformPoint
  use strict arg point
  ctx=self~context; numeric digits ctx~workingDigits+20
  r=self~matrix*.MathVector4~new(point~x,point~y,point~z,1,ctx)
  if rx_math3d_near_zero(r~w,ctx) then raise syntax 88.900 array('homogeneous point with non-zero w after transform',r~canonical)
  return .MathVector3~new(r~x/r~w,r~y/r~w,r~z/r~w,ctx,rx_math3d_evidence('transform3d.point',ctx,.array~of(self~canonical,point~canonical),'homogeneous-point-transform','Transforms w=1 point and performs perspective divide when needed.'))
::method transformDirection
  use strict arg direction
  ctx=self~context; numeric digits ctx~workingDigits+20
  r=self~matrix*.MathVector4~new(direction~x,direction~y,direction~z,0,ctx)
  return .MathVector3~new(r~x,r~y,r~z,ctx,rx_math3d_evidence('transform3d.direction',ctx,.array~of(self~canonical,direction~canonical),'homogeneous-direction-transform','Transforms w=0 direction; translation has no effect.'))
::method inverse
  ctx=self~context; numeric digits ctx~workingDigits+20
  inv=self~matrix~matrix~inverse
  return .MathTransform3D~new(.MathMatrix4~new(inv,ctx),ctx,self~convention,rx_math3d_evidence('transform3d.inverse',ctx,.array~of(self~canonical),'matrix-inverse','Uses the Maths matrix solver rather than an ad-hoc 3D inverse implementation.'))
::method toFlatArray
  use strict arg order='COLUMN_MAJOR'
  return self~matrix~toFlatArray(order)
::method toColumnMajorArray; return self~matrix~toColumnMajorArray
::method toRowMajorArray; return self~matrix~toRowMajorArray
::method lookAt class
  use strict arg eye,target,up,context=.nil,convention=.nil
  if context==.nil then context=eye~context
  if convention==.nil then convention=.Math3DConvention~openGL
  numeric digits context~workingDigits+30
  f=(target-eye)~normalized
  if convention~handedness='RIGHT_HANDED' then do
    s=f~cross(up)~normalized
    u=s~cross(f)
    rows=.array~of( -
      .array~of(s~x,s~y,s~z,-(s~dot(eye))), -
      .array~of(u~x,u~y,u~z,-(u~dot(eye))), -
      .array~of(-f~x,-f~y,-f~z,f~dot(eye)), -
      .array~of(0,0,0,1))
  end
  else do
    s=up~cross(f)~normalized
    u=f~cross(s)
    rows=.array~of( -
      .array~of(s~x,s~y,s~z,-(s~dot(eye))), -
      .array~of(u~x,u~y,u~z,-(u~dot(eye))), -
      .array~of(f~x,f~y,f~z,-(f~dot(eye))), -
      .array~of(0,0,0,1))
  end
  ev=rx_math3d_evidence('transform3d.lookAt',context,.array~of(eye~canonical,target~canonical,up~canonical,convention~canonical),'look-at-orthonormal-basis','Constructs an explicit-handedness view transform from eye, target and up.')
  return .MathAffineTransform3D~new(.MathMatrix4~new(rows,context),context,convention,ev)
::method canonical; return 'transform3d['self~convention~canonical']:'self~matrix~canonical
::method string; return self~matrix~string

::class MathAffineTransform3D subclass MathTransform3D public
::method init
  use strict arg matrix=.nil,context=.nil,convention=.nil,evidence=.nil,derivation=.nil
  if context==.nil then do
    if matrix<>.nil then do
      if matrix~isA(.MathMatrix4) then context=matrix~context
      else context=.Maths~defaultContext
    end
    else context=.Maths~defaultContext
  end
  if matrix==.nil then matrix=.MathMatrix4~identity(context)
  if \matrix~isA(.MathMatrix4) then matrix=.MathMatrix4~new(matrix,context)
  numeric digits context~workingDigits+10
  if \rx_math3d_near_zero(matrix[4,1],context) | \rx_math3d_near_zero(matrix[4,2],context) | \rx_math3d_near_zero(matrix[4,3],context) | \rx_math3d_near_zero(matrix[4,4]-1,context) then -
    raise syntax 88.900 array('affine 4x4 transform with final row [0,0,0,1]',matrix~canonical)
  self~init:super(matrix,context,convention,evidence,derivation)


::class MathProjection subclass MathTransform3D public


::class MathPerspective subclass MathProjection public
::method init
  expose _fovY _aspect _near _far
  use strict arg fovY,aspect,near,far,context=.nil,convention=.nil
  if context==.nil then context=.Maths~defaultContext
  if convention==.nil then convention=.Math3DConvention~openGL
  if \fovY~isA(.MathAngle) then fovY=.MathAngle~radians(fovY,context)
  numeric digits context~workingDigits+30
  a=rx_math3d_scalar(aspect,context); n=rx_math3d_scalar(near,context); f=rx_math3d_scalar(far,context)
  if a<=0 then raise syntax 88.900 array('positive perspective aspect',aspect)
  if n<=0 | f<=n then raise syntax 88.900 array('0 < near < far',near'/'far)
  half=fovY~radiansValue/2; pi=rx_math3d_pi(context)
  if half<=0 | half>=pi/2 then raise syntax 88.900 array('perspective vertical field of view between 0 and pi radians',fovY~canonical)
  cot=rx_math3d_cos(half,context)/rx_math3d_sin(half,context)
  m00=cot/a; m11=cot
  if convention~handedness='RIGHT_HANDED' then sign=-1; else sign=1
  if convention~depthRange='NEGATIVE_ONE_TO_ONE' then do
    if sign=-1 then do; m22=(f+n)/(n-f); m23=(2*f*n)/(n-f); end
    else do; m22=(f+n)/(f-n); m23=(-2*f*n)/(f-n); end
  end
  else do
    if sign=-1 then do; m22=f/(n-f); m23=(f*n)/(n-f); end
    else do; m22=f/(f-n); m23=(-f*n)/(f-n); end
  end
  rows=.array~of(.array~of(m00,0,0,0),.array~of(0,m11,0,0),.array~of(0,0,m22,m23),.array~of(0,0,sign,0))
  matrix=.MathMatrix4~new(rows,context)
  ev=rx_math3d_evidence('projection.perspective',context,.array~of(fovY~canonical,a,n,f,convention~canonical),'explicit-perspective-convention','Perspective projection records handedness, depth range, column-vector convention, FOV, aspect, near and far.')
  self~init:super(matrix,context,convention,ev,.MathDerivation~new('projection.perspective',.array~of(fovY),convention~canonical))
  _fovY=fovY; _aspect=a; _near=n; _far=f
::method fovY; expose _fovY; return _fovY
::method aspect; expose _aspect; return _aspect
::method near; expose _near; return _near
::method far; expose _far; return _far


::class MathOrthographic subclass MathProjection public
::method init
  expose _left _right _bottom _top _near _far
  use strict arg left,right,bottom,top,near,far,context=.nil,convention=.nil
  if context==.nil then context=.Maths~defaultContext
  if convention==.nil then convention=.Math3DConvention~openGL
  numeric digits context~workingDigits+20
  l=rx_math3d_scalar(left,context); r=rx_math3d_scalar(right,context); b=rx_math3d_scalar(bottom,context); t=rx_math3d_scalar(top,context); n=rx_math3d_scalar(near,context); f=rx_math3d_scalar(far,context)
  if r=l | t=b | f=n then raise syntax 88.900 array('non-degenerate orthographic bounds','')
  m00=2/(r-l); m11=2/(t-b); m03=-(r+l)/(r-l); m13=-(t+b)/(t-b)
  if convention~depthRange='NEGATIVE_ONE_TO_ONE' then do
    if convention~handedness='RIGHT_HANDED' then m22=-2/(f-n); else m22=2/(f-n)
    m23=-(f+n)/(f-n)
  end
  else do
    if convention~handedness='RIGHT_HANDED' then do; m22=-1/(f-n); m23=-n/(f-n); end
    else do; m22=1/(f-n); m23=-n/(f-n); end
  end
  rows=.array~of(.array~of(m00,0,0,m03),.array~of(0,m11,0,m13),.array~of(0,0,m22,m23),.array~of(0,0,0,1))
  ev=rx_math3d_evidence('projection.orthographic',context,.array~of(l,r,b,t,n,f,convention~canonical),'explicit-orthographic-convention','Orthographic projection with explicit handedness and depth range.')
  self~init:super(.MathMatrix4~new(rows,context),context,convention,ev,.MathDerivation~new('projection.orthographic',.array~new,convention~canonical))
  _left=l; _right=r; _bottom=b; _top=t; _near=n; _far=f


::class MathRay3D subclass MathValue public
::method init
  expose _origin _direction
  use strict arg origin,direction,context=.nil
  if context==.nil then context=origin~context
  self~init:super(context,rx_math3d_evidence('ray3d.construct',context,.array~of(origin~canonical,direction~canonical),'origin-normalized-direction','Ray direction is normalized at construction.'))
  _origin=origin; _direction=direction~normalized
::method origin; expose _origin; return _origin
::method direction; expose _direction; return _direction
::method pointAt
  use strict arg t
  ctx=self~context; numeric digits ctx~workingDigits
  return self~origin+self~direction*rx_math3d_scalar(t,ctx)
::method canonical; return 'ray3d['self~origin~canonical';'self~direction~canonical']'


::class MathPlane3D subclass MathValue public
::method init
  expose _normal _offset
  use strict arg normal,offset,context=.nil
  if context==.nil then context=normal~context
  self~init:super(context,rx_math3d_evidence('plane3d.construct',context,.array~of(normal~canonical,offset),'normalized-normal-offset','Plane equation n dot p + d = 0 with normalized normal.'))
  numeric digits context~workingDigits+20
  len=normal~norm; if rx_math3d_near_zero(len,context) then raise syntax 88.900 array('non-zero plane normal',normal~canonical)
  _normal=normal*(1/len); _offset=rx_math3d_scalar(offset,context)/len
::method normal; expose _normal; return _normal
::method offset; expose _offset; return _offset
::method fromPointNormal class
  use strict arg point,normal,context=.nil
  if context==.nil then context=point~context
  numeric digits context~workingDigits+20
  n=normal~normalized; d=-(n~dot(point))
  return self~new(n,d,context)
::method signedDistance
  use strict arg point
  ctx=self~context; numeric digits ctx~workingDigits
  return self~normal~dot(point)+self~offset
::method canonical; return 'plane3d['self~normal~canonical';d='self~offset']'



/* ---------- reusable numerical foundations ---------- */
::class MathScalarResult subclass MathValue public
::method init
  expose _value _operation
  use strict arg value,operation,context,evidence=.nil,derivation=.nil
  self~init:super(context,evidence,derivation)
  _value=value; _operation=operation~upper
::method value; expose _value; return _value
::method number; expose _value; return _value
::method operation; expose _operation; return _operation
::method canonical
  expose _value _operation
  v=_value; if v~hasMethod('CANONICAL') then v=v~canonical
  return 'scalar-result[' _operation ';' v ']'
::method string; expose _value; return _value
::method compute class
  use strict arg operation,value,context
  op=operation~upper
  supported=' SQRT SIN COS TAN EXP LN LOG LOG10 ATAN ATAN2 '
  if supported~pos(' 'op' ')=0 then raise syntax 88.900 array('supported scalar operation SQRT/SIN/COS/TAN/EXP/LN/LOG10/ATAN/ATAN2',operation)
  provider=.Maths~providerFor(context,'scalar.'op~lower)
  return provider~scalarCompute(op,value,context)


::class MathLinearInterpolator1D public
::method init
  expose _x _y _context _boundary
  use strict arg coordinates,values,context=.nil,boundaryPolicy='FAIL'
  if context==.nil then context=.Maths~defaultContext
  if \coordinates~isA(.array) | \values~isA(.array) then raise syntax 88.900 array('Array coordinates and values')
  if coordinates~items<2 | coordinates~items<>values~items then raise syntax 88.900 array('matching interpolation arrays with at least two points')
  _context=context; _boundary=boundaryPolicy~upper
  select
    when _boundary='FAIL' then nop
    when _boundary='CLAMP' then nop
    when _boundary='EXTRAPOLATE' then nop
    otherwise raise syntax 88.900 array('FAIL, CLAMP, or EXTRAPOLATE boundary policy',boundaryPolicy)
  end
  _x=.array~new; _y=.array~new
  numeric digits context~workingDigits
  do i=1 to coordinates~items
    xv=rx_math_coerce_value(coordinates[i],context); yv=rx_math_coerce_value(values[i],context)
    if i>1 then if xv<=_x[i-1] then raise syntax 88.900 array('strictly increasing interpolation coordinates',xv)
    _x~append(xv); _y~append(yv)
  end
::method context; expose _context; return _context
::method boundaryPolicy; expose _boundary; return _boundary
::method coordinates; expose _x; return _x~copy
::method values; expose _y; return _y~copy
::method lowerIndex private
  expose _x
  use strict arg x
  if x<=_x[1] then return 1
  if x>=_x[_x~items] then return _x~items-1
  /* binary interval search; avoids linear scans for large measured tables. */
  lo=1; hi=_x~items
  do while hi-lo>1
    mid=(lo+hi)%2
    if x<_x[mid] then hi=mid; else lo=mid
  end
  return lo
::method evaluate
  expose _x _y _context _boundary
  use strict arg coordinate
  numeric digits _context~workingDigits
  x=rx_math_coerce_value(coordinate,_context)
  first=_x[1]; last=_x[_x~items]
  if x<first then do
    if _boundary='FAIL' then raise syntax 88.900 array('interpolation coordinate inside qualified domain',x)
    if _boundary='CLAMP' then return _y[1]
  end
  if x>last then do
    if _boundary='FAIL' then raise syntax 88.900 array('interpolation coordinate inside qualified domain',x)
    if _boundary='CLAMP' then return _y[_y~items]
  end
  if x=last then return _y[_y~items]
  i=self~lowerIndex(x); x1=_x[i]; x2=_x[i+1]; y1=_y[i]; y2=_y[i+1]
  f=(x-x1)/(x2-x1)
  return y1+f*(y2-y1)
::method evaluateResult
  expose _context _boundary
  use strict arg coordinate
  value=self~evaluate(coordinate)
  ev=.MathEvidence~new('interpolate.linear1d',_context,.array~of(coordinate))
  guarantee='APPROXIMATE_HIGH_PRECISION'; if _context~numberDomain='RATIONAL' then guarantee='EXACT'
  ev~addStep(.MathPathStep~new('interpolate.linear1d','PURE','0.12','bounded-piecewise-linear',_context~numberDomain,_context~workingDigits,'MathLinearInterpolator1D','Boundary policy='_boundary'; binary interval search then affine interpolation.',guarantee,'PURE,INTERPOLATION,LINEAR1D'))
  return .MathScalarResult~new(value,'INTERPOLATE_LINEAR1D',_context,ev)

::class MathBilinearInterpolator2D public
::method init
  expose _x _y _v _context _boundary
  use strict arg xCoordinates,yCoordinates,valueRows,context=.nil,boundaryPolicy='FAIL'
  if context==.nil then context=.Maths~defaultContext
  if xCoordinates~items<2 | yCoordinates~items<2 | valueRows~items<>xCoordinates~items then raise syntax 88.900 array('two interpolation axes and matching value rows')
  _context=context; _boundary=boundaryPolicy~upper
  select
    when _boundary='FAIL' then nop
    when _boundary='CLAMP' then nop
    when _boundary='EXTRAPOLATE' then nop
    otherwise raise syntax 88.900 array('FAIL, CLAMP, or EXTRAPOLATE boundary policy',boundaryPolicy)
  end
  _x=.array~new; _y=.array~new; _v=.array~new
  numeric digits context~workingDigits
  do i=1 to xCoordinates~items
    xv=rx_math_coerce_value(xCoordinates[i],context)
    if i>1 then if xv<=_x[i-1] then raise syntax 88.900 array('strictly increasing first interpolation axis',xv)
    _x~append(xv)
  end
  do j=1 to yCoordinates~items
    yv=rx_math_coerce_value(yCoordinates[j],context)
    if j>1 then if yv<=_y[j-1] then raise syntax 88.900 array('strictly increasing second interpolation axis',yv)
    _y~append(yv)
  end
  do i=1 to valueRows~items
    if valueRows[i]~items<>_y~items then raise syntax 88.900 array('surface row matching second interpolation axis',i)
    row=.array~new
    do j=1 to valueRows[i]~items; row~append(rx_math_coerce_value(valueRows[i][j],context)); end
    _v~append(row)
  end
::method context; expose _context; return _context
::method boundaryPolicy; expose _boundary; return _boundary
::method lowerIndex private
  use strict arg axis,value
  if value<=axis[1] then return 1
  if value>=axis[axis~items] then return axis~items-1
  lo=1; hi=axis~items
  do while hi-lo>1
    mid=(lo+hi)%2
    if value<axis[mid] then hi=mid; else lo=mid
  end
  return lo
::method evaluate
  expose _x _y _v _context _boundary
  use strict arg xValue,yValue
  numeric digits _context~workingDigits
  x=rx_math_coerce_value(xValue,_context); y=rx_math_coerce_value(yValue,_context)
  if _boundary='FAIL' then do
    if x<_x[1] | x>_x[_x~items] | y<_y[1] | y>_y[_y~items] then raise syntax 88.900 array('bilinear interpolation point inside qualified domain',x y)
  end
  if _boundary='CLAMP' then do
    if x<_x[1] then x=_x[1]; if x>_x[_x~items] then x=_x[_x~items]
    if y<_y[1] then y=_y[1]; if y>_y[_y~items] then y=_y[_y~items]
  end
  xi=self~lowerIndex(_x,x); yi=self~lowerIndex(_y,y)
  x1=_x[xi]; x2=_x[xi+1]; y1=_y[yi]; y2=_y[yi+1]
  fx=(x-x1)/(x2-x1); fy=(y-y1)/(y2-y1)
  v11=_v[xi][yi]; v12=_v[xi][yi+1]; v21=_v[xi+1][yi]; v22=_v[xi+1][yi+1]
  low=v11+fy*(v12-v11); high=v21+fy*(v22-v21)
  return low+fx*(high-low)
::method evaluateResult
  expose _context _boundary
  use strict arg x,y
  value=self~evaluate(x,y)
  ev=.MathEvidence~new('interpolate.bilinear2d',_context,.array~of(x,y))
  guarantee='APPROXIMATE_HIGH_PRECISION'; if _context~numberDomain='RATIONAL' then guarantee='EXACT'
  ev~addStep(.MathPathStep~new('interpolate.bilinear2d','PURE','0.12','bounded-bilinear',_context~numberDomain,_context~workingDigits,'MathBilinearInterpolator2D','Boundary policy='_boundary'; independent interval search on each axis followed by bilinear blend.',guarantee,'PURE,INTERPOLATION,BILINEAR2D'))
  return .MathScalarResult~new(value,'INTERPOLATE_BILINEAR2D',_context,ev)

::class MathSampledScalarSeries public
::method init
  expose _times _values _context
  use strict arg context=.nil
  if context==.nil then context=.Maths~defaultContext
  _context=context; _times=.array~new; _values=.array~new
::method context; expose _context; return _context
::method append
  expose _times _values _context
  use strict arg time,value
  numeric digits _context~workingDigits
  t=rx_math_coerce_value(time,_context); v=rx_math_coerce_value(value,_context)
  if _times~items>0 then if t<=_times[_times~items] then raise syntax 88.900 array('strictly increasing sample times',t)
  _times~append(t); _values~append(v); return self
::method count; expose _values; return _values~items
::method times; expose _times; return _times~copy
::method values; expose _values; return _values~copy
::method duration
  expose _times
  if _times~items<2 then return 0
  return _times[_times~items]-_times[1]
::method mean
  expose _context
  return .Maths~providerFor(_context,'series.mean')~seriesMean(self,_context)
::method rms
  expose _context
  return .Maths~providerFor(_context,'series.rms')~seriesRms(self,_context)
::method isUniform
  expose _times _context
  use strict arg tolerance=.nil
  if _times~items<3 then return .true
  if tolerance==.nil then tolerance=_context~absoluteTolerance
  numeric digits _context~workingDigits+8
  dt=_times[2]-_times[1]
  do i=3 to _times~items
    if ((_times[i]-_times[i-1])-dt)~abs>tolerance then return .false
  end
  return .true
::method fourierComponent
  expose _context
  use strict arg frequency
  return .Maths~providerFor(_context,'spectrum.selected-frequency')~seriesFourierComponent(self,frequency,_context)
::method component; use strict arg frequency; return self~fourierComponent(frequency)
::method spectrum
  expose _context
  use strict arg frequencies
  return .Maths~providerFor(_context,'spectrum.selected-frequencies')~seriesSpectrum(self,frequencies,_context)
::method rfft
  expose _context
  return .Maths~providerFor(_context,'spectrum.rfft')~seriesRfft(self,_context)

::class MathFFTBin public
::method init
  expose _index _frequency _real _imaginary _samples _context
  use strict arg index,frequencyHz,realPart,imaginaryPart,sampleCount,context
  _index=index; _frequency=frequencyHz; _real=realPart; _imaginary=imaginaryPart; _samples=sampleCount; _context=context
::method index; expose _index; return _index
::method frequencyHz; expose _frequency; return _frequency
::method real; expose _real; return _real
::method imaginary; expose _imaginary; return _imaginary
::method sampleCount; expose _samples; return _samples
::method coefficient
  expose _real _imaginary _context
  return .MathComplex~new(_real,_imaginary,_context)
::method magnitude
  expose _real _imaginary _context
  return rx_math_numeric_sqrt(_real*_real+_imaginary*_imaginary,_context)
::method canonical
  expose _index _frequency _real _imaginary _samples
  return 'fft-bin[index='_index';f='_frequency';real='_real';imag='_imaginary';n='_samples']'
::method string; return self~canonical

::class MathFFTResult subclass MathValue public
::method init
  expose _bins _sampleRate _sampleCount _timeOrigin
  use strict arg bins,sampleRate,sampleCount,timeOrigin,context,evidence=.nil,derivation=.nil
  self~init:super(context,evidence,derivation)
  _bins=bins~copy; _sampleRate=sampleRate; _sampleCount=sampleCount; _timeOrigin=timeOrigin
::method bins; expose _bins; return _bins~copy
::method bin
  expose _bins
  use strict arg index
  return _bins[index+1]
::method binCount; expose _bins; return _bins~items
::method sampleRate; expose _sampleRate; return _sampleRate
::method sampleCount; expose _sampleCount; return _sampleCount
::method timeOrigin; expose _timeOrigin; return _timeOrigin
::method maxAbsDifference
  expose _bins
  use strict arg other
  if self~binCount<>other~binCount then return 'INF'
  numeric digits max(self~context~verificationContext~workingDigits,other~context~verificationContext~workingDigits)
  otherBins=other~bins; m=0
  do i=1 to _bins~items
    a=_bins[i]; b=otherBins[i]
    d=(a~real-b~real)~abs; if d>m then m=d
    d=(a~imaginary-b~imaginary)~abs; if d>m then m=d
  end
  return m
::method canonical
  expose _bins _sampleRate _sampleCount _timeOrigin
  s='rfft[n='_sampleCount';rate='_sampleRate';t0='_timeOrigin';bins='_bins~items']'
  do b over _bins; s=s || '|' || b~canonical; end
  return s
::method string; return self~canonical

::class MathSpectralComponent subclass MathValue public
::method init
  expose _frequency _amplitude _cosine _sine _samples
  use strict arg frequency,amplitude,cosineComponent,sineComponent,sampleCount,context,evidence=.nil,derivation=.nil
  self~init:super(context,evidence,derivation)
  _frequency=frequency; _amplitude=amplitude; _cosine=cosineComponent; _sine=sineComponent; _samples=sampleCount
::method frequency; expose _frequency; return _frequency
::method amplitude; expose _amplitude; return _amplitude
::method cosineComponent; expose _cosine; return _cosine
::method sineComponent; expose _sine; return _sine
::method sampleCount; expose _samples; return _samples
::method canonical
  expose _frequency _amplitude _cosine _sine _samples
  return 'spectral-component[f='_frequency';a='_amplitude';c='_cosine';s='_sine';n='_samples']'
::method string; return self~canonical

::class MathDampedOscillatorBank public
::method init
  expose _amplitudes _frequencies _decays _phases _sampleRate _context
  use strict arg amplitudes,frequenciesHz,decayPerSecond,phaseRadians=.nil,sampleRate=48000,context=.nil
  if context==.nil then context=.Maths~defaultContext
  if \amplitudes~isA(.array) | \frequenciesHz~isA(.array) | \decayPerSecond~isA(.array) then raise syntax 88.900 array('Array oscillator parameters')
  if amplitudes~items=0 | amplitudes~items<>frequenciesHz~items | amplitudes~items<>decayPerSecond~items then raise syntax 88.900 array('equal non-empty oscillator parameter arrays')
  if phaseRadians==.nil then do; phaseRadians=.array~new; do i=1 to amplitudes~items; phaseRadians~append(0); end; end
  if \phaseRadians~isA(.array) | phaseRadians~items<>amplitudes~items then raise syntax 88.900 array('phase array matching oscillator count')
  if sampleRate<=0 then raise syntax 88.900 array('positive oscillator sample rate',sampleRate)
  _context=context; numeric digits context~workingDigits
  _amplitudes=.array~new; _frequencies=.array~new; _decays=.array~new; _phases=.array~new
  do i=1 to amplitudes~items
    a=rx_math_coerce_value(amplitudes[i],context); f=rx_math_coerce_value(frequenciesHz[i],context); d=rx_math_coerce_value(decayPerSecond[i],context); ph=rx_math_coerce_value(phaseRadians[i],context)
    if f<0 | d<0 then raise syntax 88.900 array('non-negative oscillator frequency and decay',f d)
    _amplitudes~append(a); _frequencies~append(f); _decays~append(d); _phases~append(ph)
  end
  _sampleRate=rx_math_coerce_value(sampleRate,context)
::method context; expose _context; return _context
::method modeCount; expose _amplitudes; return _amplitudes~items
::method amplitudes; expose _amplitudes; return _amplitudes~copy
::method frequenciesHz; expose _frequencies; return _frequencies~copy
::method decayPerSecond; expose _decays; return _decays~copy
::method phaseRadians; expose _phases; return _phases~copy
::method sampleRate; expose _sampleRate; return _sampleRate
::method render
  expose _context
  use strict arg sampleCount,startSample=0
  return .Maths~providerFor(_context,'signal.oscillator-bank')~oscillatorBankRender(self,sampleCount,startSample,_context)
::method canonical
  expose _amplitudes _frequencies _decays _phases _sampleRate
  s='oscillator-bank[rate='_sampleRate';modes='_amplitudes~items']'
  do i=1 to _amplitudes~items; s=s || '|a=' || _amplitudes[i] || ';f=' || _frequencies[i] || ';d=' || _decays[i] || ';p=' || _phases[i]; end
  return s
::method string; return self~canonical

::class MathQuadraticEquation public
::method init
  expose _a _b _c _context
  use strict arg a,b,c,context=.nil
  if context==.nil then context=.Maths~defaultContext
  _context=context; numeric digits context~workingDigits
  _a=rx_math_coerce_value(a,context); _b=rx_math_coerce_value(b,context); _c=rx_math_coerce_value(c,context)
  if _a=0 then raise syntax 88.900 array('non-zero quadratic coefficient a',a)
::method a; expose _a; return _a
::method b; expose _b; return _b
::method c; expose _c; return _c
::method context; expose _context; return _context
::method discriminant
  expose _a _b _c _context
  numeric digits _context~workingDigits+12
  return _b*_b-4*_a*_c
::method solve
  expose _a _b _c _context
  numeric digits _context~workingDigits+24
  d=self~discriminant
  ev=.MathEvidence~new('quadratic.solve',_context,.array~of(_a,_b,_c))
  if d>=0 then do
    root=rx_math_numeric_sqrt(d,_context)
    if _b>=0 then q=(-_b-root)/2; else q=(-_b+root)/2
    if q=0 then do; r1=-_b/(2*_a); r2=r1; end
    else do; r1=q/_a; r2=_c/q; end
    guarantee='APPROXIMATE_HIGH_PRECISION'; if _context~numberDomain='RATIONAL' then guarantee='EXACT'
    ev~addStep(.MathPathStep~new('quadratic.solve','PURE','0.12','stable-q-formula',_context~numberDomain,_context~workingDigits,'MathQuadraticEquation','Uses q=-1/2*(b+sign(b)*sqrt(discriminant)); second root c/q to reduce cancellation.',guarantee,'PURE,POLYNOMIAL,QUADRATIC'))
    ev~putCheck('discriminant',d)
    return .MathQuadraticRoots~new(r1,r2,d,.true,_context,ev)
  end
  if _context~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for non-real quadratic roots',d)
  root=rx_math_numeric_sqrt(-d,_context); real=-_b/(2*_a); imag=root/(2*_a)
  r1=.MathComplex~new(real,imag,_context); r2=.MathComplex~new(real,-imag,_context)
  ev~addStep(.MathPathStep~new('quadratic.solve','PURE','0.12','complex-conjugate-quadratic-roots',_context~numberDomain,_context~workingDigits,'MathQuadraticEquation','Negative discriminant represented as a conjugate MathComplex pair.','APPROXIMATE_HIGH_PRECISION','PURE,POLYNOMIAL,QUADRATIC,COMPLEX'))
  ev~putCheck('discriminant',d)
  return .MathQuadraticRoots~new(r1,r2,d,.false,_context,ev)

::class MathQuadraticRoots subclass MathValue public
::method init
  expose _r1 _r2 _disc _real
  use strict arg root1,root2,discriminant,realRoots,context,evidence=.nil
  self~init:super(context,evidence,.nil)
  _r1=root1; _r2=root2; _disc=discriminant; _real=realRoots
::method root1; expose _r1; return _r1
::method root2; expose _r2; return _r2
::method roots; expose _r1 _r2; return .array~of(_r1,_r2)
::method discriminant; expose _disc; return _disc
::method hasRealRoots; expose _real; return _real
::method smallestPositive
  expose _r1 _r2 _real
  use strict arg epsilon=0
  if \_real then return .nil
  best=.nil
  if _r1>epsilon then best=_r1
  if _r2>epsilon then do; if best==.nil | _r2<best then best=_r2; end
  return best
::method canonical
  expose _r1 _r2 _disc _real
  a=_r1; b=_r2; if a~hasMethod('CANONICAL') then a=a~canonical; if b~hasMethod('CANONICAL') then b=b~canonical
  return 'quadratic-roots[real=' || _real || ';disc=' || _disc || ';r1=' || a || ';r2=' || b || ']' 
::method string; return self~canonical

::class MathLinearSystem public
::method init
  expose _a _b _context
  use strict arg coefficients,rhs,context=.nil
  if context==.nil then context=.Maths~defaultContext
  _context=context
  if coefficients~isA(.MathMatrix) then _a=coefficients; else _a=.MathMatrix~new(coefficients,context)
  if rhs~isA(.MathVector) then _b=rhs; else _b=.MathVector~new(rhs,context)
  if _a~rows<>_a~cols | _a~rows<>_b~size then raise syntax 88.900 array('square coefficient matrix and matching right-hand side',_a~rows _a~cols _b~size)
::method coefficientMatrix; expose _a; return _a
::method rhs; expose _b; return _b
::method context; expose _context; return _context
::method solve; expose _a _b; return _a~solve(_b)
::method residual
  expose _a _b
  use strict arg solution
  return (_a*solution)-_b

/* Generic discrete-time linear state-space system.
 * Channel semantics remain with the caller.  Maths owns only
 *   x[k+1] = A*x[k] + B*u[k]
 *   y[k]   = C*x[k] + D*u[k]
 * and checkpointable continuation of the state vector. */
::class MathDiscreteStateSpaceSystem public
::method init
  expose _a _b _c _d _context _states _inputs _outputs
  use strict arg stateMatrix,inputMatrix,outputMatrix,feedthroughMatrix,context=.nil
  if context==.nil then context=.Maths~defaultContext
  _context=context
  if stateMatrix~isA(.MathMatrix) then _a=.MathMatrix~new(stateMatrix~toArray,context); else _a=.MathMatrix~new(stateMatrix,context)
  if inputMatrix~isA(.MathMatrix) then _b=.MathMatrix~new(inputMatrix~toArray,context); else _b=.MathMatrix~new(inputMatrix,context)
  if outputMatrix~isA(.MathMatrix) then _c=.MathMatrix~new(outputMatrix~toArray,context); else _c=.MathMatrix~new(outputMatrix,context)
  if feedthroughMatrix~isA(.MathMatrix) then _d=.MathMatrix~new(feedthroughMatrix~toArray,context); else _d=.MathMatrix~new(feedthroughMatrix,context)
  if \_a~isSquare | _a~rows<1 then raise syntax 88.900 array('non-empty square discrete state matrix A')
  _states=_a~rows
  if _b~rows<>_states | _b~cols<1 then raise syntax 88.900 array('B rows matching state count and at least one input',_states)
  _inputs=_b~cols
  if _c~cols<>_states | _c~rows<1 then raise syntax 88.900 array('C columns matching state count and at least one output',_states)
  _outputs=_c~rows
  if _d~rows<>_outputs | _d~cols<>_inputs then raise syntax 88.900 array('D shape matching output/input counts',_outputs,_inputs)
::method context; expose _context; return _context
::method stateMatrix; expose _a; return _a
::method inputMatrix; expose _b; return _b
::method outputMatrix; expose _c; return _c
::method feedthroughMatrix; expose _d; return _d
::method stateCount; expose _states; return _states
::method inputCount; expose _inputs; return _inputs
::method outputCount; expose _outputs; return _outputs
::method zeroState
  expose _states _context
  a=.array~new; do i=1 to _states; a~append(rx_math_zero(_context)); end
  return .MathVector~new(a,_context)
::method process
  expose _context _states
  use strict arg inputs,initialState=.nil
  if initialState==.nil then initialState=self~zeroState
  if initialState~isA(.MathVector) then x=.MathVector~new(initialState~toArray,_context); else x=.MathVector~new(initialState,_context)
  if x~size<>_states then raise syntax 88.900 array('discrete initial state matching state count',_states,x~size)
  if inputs~isA(.MathMatrix) then U=.MathMatrix~new(inputs~toArray,_context); else U=.MathMatrix~new(inputs,_context)
  if U~cols<>self~inputCount then raise syntax 88.900 array('discrete input history columns matching input count',self~inputCount,U~cols)
  /* Current Foreign Runtime list marshalling dominates low-order scalar recurrences.
     AUTO therefore keeps very small state systems local, and only selects the
     native provider once matrix-state work is large enough to amortize the bridge. */
  if _context~provider='AUTO' then do
    if _context~numberDomain='BINARY64' then do
      work=_states*_states*U~rows
      if _states<=4 | work<250000 then p=.Maths~provider('PURE')
      else p=.Maths~providerFor(_context,'signal.state-space')
    end
    else p=.Maths~providerFor(_context,'signal.state-space')
  end
  else p=.Maths~providerFor(_context,'signal.state-space')
  return p~discreteStateSpaceProcess(self,x,U,_context)
::method continuation
  use strict arg initialState=.nil
  return .MathDiscreteStateContinuation~new(self,initialState)
::method canonical
  expose _a _b _c _d _states _inputs _outputs
  return 'discrete-state-space[n='_states';inputs='_inputs';outputs='_outputs';A={'_a~canonical'};B={'_b~canonical'};C={'_c~canonical'};D={'_d~canonical'}]'
::method string; return self~canonical

::class MathDiscreteStateSpaceTrajectory subclass MathValue public
::method init
  expose _outputs _final _samples
  use strict arg outputs,finalState,sampleCount,context,evidence=.nil,derivation=.nil
  self~init:super(context,evidence,derivation)
  if outputs~isA(.MathMatrix) then _outputs=outputs; else _outputs=.MathMatrix~new(outputs,context)
  if finalState~isA(.MathVector) then _final=finalState; else _final=.MathVector~new(finalState,context)
  _samples=sampleCount
::method outputs; expose _outputs; return _outputs
::method finalState; expose _final; return _final
::method sampleCount; expose _samples; return _samples
::method outputCount; expose _outputs; return _outputs~cols
::method outputChannel
  expose _outputs
  use strict arg channel
  if \datatype(channel,'W') | channel<1 | channel>_outputs~cols then raise syntax 88.900 array('valid discrete output channel',channel)
  a=.array~new; do i=1 to _outputs~rows; a~append(_outputs[i,channel]); end
  return .MathVector~new(a,self~context,self~evidence)
::method canonical
  expose _samples _outputs
  return 'discrete-state-trajectory[samples='_samples';outputs='_outputs~cols']'
::method string; return self~canonical

::class MathDiscreteStateSnapshot public
::method init
  expose _state _samples _context
  use strict arg state,samplesProcessed,context
  if state~isA(.MathVector) then _state=.MathVector~new(state~toArray,context); else _state=.MathVector~new(state,context)
  _samples=samplesProcessed; _context=context
::method state; expose _state _context; return .MathVector~new(_state~toArray,_context)
::method samplesProcessed; expose _samples; return _samples
::method context; expose _context; return _context

::class MathDiscreteStateContinuation public
::method init
  expose _system _state _samples _last
  use strict arg system,initialState=.nil
  if \system~isA(.MathDiscreteStateSpaceSystem) then raise syntax 88.900 array('MathDiscreteStateSpaceSystem',system)
  _system=system
  if initialState==.nil then _state=system~zeroState
  else if initialState~isA(.MathVector) then _state=.MathVector~new(initialState~toArray,system~context)
  else _state=.MathVector~new(initialState,system~context)
  if _state~size<>system~stateCount then raise syntax 88.900 array('continuation state matching discrete state count',system~stateCount)
  _samples=0; _last=.nil
::method system; expose _system; return _system
::method state; expose _state; return _state
::method samplesProcessed; expose _samples; return _samples
::method lastTrajectory; expose _last; return _last
::method advance
  expose _system _state _samples _last
  use strict arg inputs
  _last=_system~process(inputs,_state)
  _state=_last~finalState; _samples+=_last~sampleCount
  return _last
::method snapshot
  expose _state _samples _system
  return .MathDiscreteStateSnapshot~new(_state,_samples,_system~context)
::method restore
  expose _state _samples _last _system
  use strict arg snapshot
  if \snapshot~isA(.MathDiscreteStateSnapshot) then raise syntax 88.900 array('MathDiscreteStateSnapshot',snapshot)
  st=snapshot~state
  if st~size<>_system~stateCount then raise syntax 88.900 array('snapshot state matching discrete state count',_system~stateCount)
  _state=.MathVector~new(st~toArray,_system~context); _samples=snapshot~samplesProcessed; _last=.nil
  return self
::method reset
  expose _state _samples _last _system
  use strict arg state=.nil
  if state==.nil then _state=_system~zeroState
  else if state~isA(.MathVector) then _state=.MathVector~new(state~toArray,_system~context)
  else _state=.MathVector~new(state,_system~context)
  if _state~size<>_system~stateCount then raise syntax 88.900 array('reset state matching discrete state count',_system~stateCount)
  _samples=0; _last=.nil; return self

/* Generic constant-coefficient second-order linear dynamics.
 * Physical ownership stays with the caller: Maths only owns numerical
 * propagation of M*x'' + C*x' + K*x = f(t). */
::class MathSecondOrderLinearSystem public
::method init
  expose _mass _damping _stiffness _context _dimension
  use strict arg massMatrix,dampingMatrix,stiffnessMatrix,context=.nil
  if context==.nil then context=.Maths~defaultContext
  _context=context
  if massMatrix~isA(.MathMatrix) then _mass=.MathMatrix~new(massMatrix~toArray,context); else _mass=.MathMatrix~new(massMatrix,context)
  if dampingMatrix~isA(.MathMatrix) then _damping=.MathMatrix~new(dampingMatrix~toArray,context); else _damping=.MathMatrix~new(dampingMatrix,context)
  if stiffnessMatrix~isA(.MathMatrix) then _stiffness=.MathMatrix~new(stiffnessMatrix~toArray,context); else _stiffness=.MathMatrix~new(stiffnessMatrix,context)
  if \_mass~isSquare | \_damping~isSquare | \_stiffness~isSquare then raise syntax 88.900 array('square M, C and K matrices')
  if _mass~rows<>_damping~rows | _mass~rows<>_stiffness~rows then raise syntax 88.900 array('matching M, C and K dimensions')
  _dimension=_mass~rows
  if _dimension<1 then raise syntax 88.900 array('non-empty second-order system')
::method context; expose _context; return _context
::method dimension; expose _dimension; return _dimension
::method massMatrix; expose _mass; return _mass
::method dampingMatrix; expose _damping; return _damping
::method stiffnessMatrix; expose _stiffness; return _stiffness
::method withContext
  expose _mass _damping _stiffness
  use strict arg context
  return self~class~new(_mass~toArray,_damping~toArray,_stiffness~toArray,context)
::method integrate
  expose _context _dimension
  use strict arg initialDisplacement,initialVelocity,dt,steps,forces=.nil,startTime=0,method='NEWMARK_AVERAGE_ACCELERATION'
  if initialDisplacement~isA(.MathVector) then x0=.MathVector~new(initialDisplacement~toArray,_context); else x0=.MathVector~new(initialDisplacement,_context)
  if initialVelocity~isA(.MathVector) then v0=.MathVector~new(initialVelocity~toArray,_context); else v0=.MathVector~new(initialVelocity,_context)
  if x0~size<>_dimension | v0~size<>_dimension then raise syntax 88.900 array('initial displacement/velocity matching dynamics dimension',_dimension)
  if dt<=0 then raise syntax 88.900 array('positive dynamics time step',dt)
  if \datatype(steps,'W') | steps<1 then raise syntax 88.900 array('positive integer dynamics step count',steps)
  methodKey=method~upper
  select
    when methodKey='NEWMARK_AVERAGE_ACCELERATION' then nop
    when methodKey='NEWMARK' then nop
    when methodKey='SYMPLECTIC_EULER' then nop
    otherwise raise syntax 88.900 array('NEWMARK_AVERAGE_ACCELERATION or SYMPLECTIC_EULER dynamics method',method)
  end
  return .Maths~providerFor(_context,'dynamics.second-order.integrate')~secondOrderIntegrate(self,x0,v0,dt,steps,forces,startTime,method~upper,_context)
::method integrateFinal
  expose _context _dimension
  use strict arg initialDisplacement,initialVelocity,dt,steps,forces=.nil,startTime=0,method='NEWMARK_AVERAGE_ACCELERATION'
  if initialDisplacement~isA(.MathVector) then x0=.MathVector~new(initialDisplacement~toArray,_context); else x0=.MathVector~new(initialDisplacement,_context)
  if initialVelocity~isA(.MathVector) then v0=.MathVector~new(initialVelocity~toArray,_context); else v0=.MathVector~new(initialVelocity,_context)
  if x0~size<>_dimension | v0~size<>_dimension then raise syntax 88.900 array('initial displacement/velocity matching dynamics dimension',_dimension)
  if dt<=0 then raise syntax 88.900 array('positive dynamics time step',dt)
  if \datatype(steps,'W') | steps<1 then raise syntax 88.900 array('positive integer dynamics step count',steps)
  methodKey=method~upper
  select
    when methodKey='NEWMARK_AVERAGE_ACCELERATION' then nop
    when methodKey='NEWMARK' then nop
    when methodKey='SYMPLECTIC_EULER' then nop
    otherwise raise syntax 88.900 array('NEWMARK_AVERAGE_ACCELERATION or SYMPLECTIC_EULER dynamics method',method)
  end
  return .Maths~providerFor(_context,'dynamics.second-order.final')~secondOrderIntegrateFinal(self,x0,v0,dt,steps,forces,startTime,method~upper,_context)
::method canonical
  expose _mass _damping _stiffness _dimension
  return 'second-order-linear-system[n='_dimension';M={'_mass~canonical'};C={'_damping~canonical'};K={'_stiffness~canonical'}]'
::method string; return self~canonical

/* Linear input/output projection around a second-order system.
 * The caller owns the meaning of each input/output channel. Maths owns only
 * B*u forcing and y=Hx*x+Hv*v projection around the M,C,K propagation. */
::class MathSecondOrderInputOutputSystem public
::method init
  expose _system _input _hx _hv _context _inputs _outputs
  use strict arg system,inputMatrix,displacementOutputMatrix,velocityOutputMatrix,context=.nil
  if \system~isA(.MathSecondOrderLinearSystem) then raise syntax 88.900 array('MathSecondOrderLinearSystem',system)
  if context==.nil then context=system~context
  _context=context; _system=system~withContext(context)
  if inputMatrix~isA(.MathMatrix) then _input=.MathMatrix~new(inputMatrix~toArray,context); else _input=.MathMatrix~new(inputMatrix,context)
  if displacementOutputMatrix~isA(.MathMatrix) then _hx=.MathMatrix~new(displacementOutputMatrix~toArray,context); else _hx=.MathMatrix~new(displacementOutputMatrix,context)
  if velocityOutputMatrix~isA(.MathMatrix) then _hv=.MathMatrix~new(velocityOutputMatrix~toArray,context); else _hv=.MathMatrix~new(velocityOutputMatrix,context)
  if _input~rows<>_system~dimension then raise syntax 88.900 array('input matrix rows matching dynamics dimension',_system~dimension,_input~rows)
  if _hx~cols<>_system~dimension | _hv~cols<>_system~dimension then raise syntax 88.900 array('output matrix columns matching dynamics dimension',_system~dimension)
  if _hx~rows<>_hv~rows then raise syntax 88.900 array('matching displacement/velocity output channel counts',_hx~rows,_hv~rows)
  _inputs=_input~cols; _outputs=_hx~rows
::method system; expose _system; return _system
::method context; expose _context; return _context
::method inputMatrix; expose _input; return _input
::method displacementOutputMatrix; expose _hx; return _hx
::method velocityOutputMatrix; expose _hv; return _hv
::method inputCount; expose _inputs; return _inputs
::method outputCount; expose _outputs; return _outputs
::method integrateProjected
  expose _context _system
  use strict arg initialDisplacement,initialVelocity,dt,steps,inputs=.nil,startTime=0,method='SYMPLECTIC_EULER'
  if initialDisplacement~isA(.MathVector) then x0=.MathVector~new(initialDisplacement~toArray,_context); else x0=.MathVector~new(initialDisplacement,_context)
  if initialVelocity~isA(.MathVector) then v0=.MathVector~new(initialVelocity~toArray,_context); else v0=.MathVector~new(initialVelocity,_context)
  if x0~size<>_system~dimension | v0~size<>_system~dimension then raise syntax 88.900 array('initial displacement/velocity matching dynamics dimension',_system~dimension)
  if dt<=0 then raise syntax 88.900 array('positive dynamics time step',dt)
  if \datatype(steps,'W') | steps<1 then raise syntax 88.900 array('positive integer dynamics step count',steps)
  return .Maths~providerFor(_context,'dynamics.second-order.io')~secondOrderIntegrateProjected(self,x0,v0,dt,steps,inputs,startTime,method~upper,_context)
::method canonical
  expose _system _input _hx _hv _inputs _outputs
  return 'second-order-io-system[n='_system~dimension';inputs='_inputs';outputs='_outputs';B={'_input~canonical'};Hx={'_hx~canonical'};Hv={'_hv~canonical'}]'
::method string; return self~canonical

::class MathSecondOrderProjectedTrajectory subclass MathValue public
::method init
  expose _times _outputs _final _dt _start
  use strict arg times,outputs,finalState,dt,startTime,context,evidence=.nil,derivation=.nil
  self~init:super(context,evidence,derivation)
  _times=times~copy
  if outputs~isA(.MathMatrix) then _outputs=outputs; else _outputs=.MathMatrix~new(outputs,context)
  _final=finalState; _dt=dt; _start=startTime
::method times; expose _times; return _times~copy
::method outputs; expose _outputs; return _outputs
::method finalState; expose _final; return _final
::method dt; expose _dt; return _dt
::method startTime; expose _start; return _start
::method sampleCount; expose _times; return _times~items
::method outputCount; expose _outputs; return _outputs~cols
::method outputChannel
  expose _outputs
  use strict arg channel
  if \datatype(channel,'W') | channel<1 | channel>_outputs~cols then raise syntax 88.900 array('valid projected output channel',channel)
  a=.array~new; do i=1 to _outputs~rows; a~append(_outputs[i,channel]); end
  return .MathVector~new(a,self~context,self~evidence)
::method canonical
  expose _times _outputs
  return 'second-order-projected-trajectory[samples='_times~items';outputs='_outputs~cols']'
::method string; return self~canonical

/* Stateful discrete sample delay for causal block-processing boundaries.
 * Maths owns only discrete delay/state semantics.  A domain package decides
 * whether a delayed sample represents pressure, voltage, force, etc. */
::class MathDelayLineState public
::method init
  expose _delay _cursor _values _context
  use strict arg delaySamples,cursor,values,context
  _delay=delaySamples; _cursor=cursor; _values=values~copy; _context=context
::method delaySamples; expose _delay; return _delay
::method cursor; expose _cursor; return _cursor
::method values; expose _values; return _values~copy
::method context; expose _context; return _context

::class MathSampleDelayLine public
::method init
  expose _delay _cursor _values _context _initial
  use strict arg delaySamples,initialValue=0,context=.nil
  if context==.nil then context=.Maths~defaultContext
  if \datatype(delaySamples,'W') | delaySamples<0 then raise syntax 88.900 array('non-negative integer sample delay',delaySamples)
  _delay=delaySamples; _context=context; _initial=initialValue; _cursor=1
  _values=.array~new
  do i=1 to delaySamples; _values[i]=initialValue; end
::method delaySamples; expose _delay; return _delay
::method context; expose _context; return _context
::method push
  expose _delay _cursor _values
  use strict arg value
  if _delay=0 then return value
  out=_values[_cursor]; _values[_cursor]=value
  _cursor+=1; if _cursor>_delay then _cursor=1
  return out
::method process
  expose _context
  use strict arg samples
  if samples~isA(.MathVector) then a=samples~toArray; else a=samples
  out=.array~new
  do i=1 to a~items; out[i]=self~push(a[i]); end
  return .MathVector~new(out,_context)
::method snapshot
  expose _delay _cursor _values _context
  return .MathDelayLineState~new(_delay,_cursor,_values,_context)
::method restore
  expose _delay _cursor _values _context
  use strict arg state
  if \state~isA(.MathDelayLineState) then raise syntax 88.900 array('MathDelayLineState',state)
  if state~delaySamples<>_delay then raise syntax 88.900 array('matching sample-delay state',state~delaySamples,_delay)
  _cursor=state~cursor; _values=state~values; _context=state~context
  return self
::method reset
  expose _delay _cursor _values _initial
  _cursor=1; _values=.array~new
  do i=1 to _delay; _values[i]=_initial; end
  return self

/* Continuation wrapper for second-order systems.  It makes block boundaries
 * explicit while retaining exactly the same integrator/provider semantics as
 * MathSecondOrderLinearSystem~integrate.  In a delayed closed loop, a caller
 * may choose blocks no longer than the already-known causal delay, compute the
 * domain-specific feedback between blocks, then resume from this state. */
::class MathSecondOrderContinuation public
::method init
  expose _system _context _x _v _time _method _last
  use strict arg system,initialDisplacement,initialVelocity,startTime=0,method='SYMPLECTIC_EULER'
  if \system~isA(.MathSecondOrderLinearSystem) then raise syntax 88.900 array('MathSecondOrderLinearSystem',system)
  _system=system; _context=system~context; _time=startTime; _method=method~upper; _last=.nil
  if initialDisplacement~isA(.MathVector) then _x=.MathVector~new(initialDisplacement~toArray,_context); else _x=.MathVector~new(initialDisplacement,_context)
  if initialVelocity~isA(.MathVector) then _v=.MathVector~new(initialVelocity~toArray,_context); else _v=.MathVector~new(initialVelocity,_context)
  if _x~size<>system~dimension | _v~size<>system~dimension then raise syntax 88.900 array('continuation state matching dynamics dimension',system~dimension)
  select
    when _method='NEWMARK_AVERAGE_ACCELERATION' then nop
    when _method='NEWMARK' then nop
    when _method='SYMPLECTIC_EULER' then nop
    otherwise raise syntax 88.900 array('NEWMARK_AVERAGE_ACCELERATION or SYMPLECTIC_EULER dynamics method',method)
  end
::method system; expose _system; return _system
::method context; expose _context; return _context
::method time; expose _time; return _time
::method displacement; expose _x; return _x
::method velocity; expose _v; return _v
::method method; expose _method; return _method
::method lastState; expose _last; return _last
::method advance
  expose _system _x _v _time _method _last
  use strict arg dt,steps,forces=.nil
  tr=_system~integrate(_x,_v,dt,steps,forces,_time,_method)
  _last=tr~finalState; _x=_last~displacement; _v=_last~velocity; _time=_last~time
  return tr
::method advanceFinal
  expose _system _x _v _time _method _last
  use strict arg dt,steps,forces=.nil
  _last=_system~integrateFinal(_x,_v,dt,steps,forces,_time,_method)
  _x=_last~displacement; _v=_last~velocity; _time=_last~time
  return _last
::method reset
  expose _x _v _time _last _context _system
  use strict arg displacement,velocity,startTime=0
  if displacement~isA(.MathVector) then _x=.MathVector~new(displacement~toArray,_context); else _x=.MathVector~new(displacement,_context)
  if velocity~isA(.MathVector) then _v=.MathVector~new(velocity~toArray,_context); else _v=.MathVector~new(velocity,_context)
  if _x~size<>_system~dimension | _v~size<>_system~dimension then raise syntax 88.900 array('continuation state matching dynamics dimension',_system~dimension)
  _time=startTime; _last=.nil
  return self

::class MathSecondOrderState subclass MathValue public
::method init
  expose _time _x _v _a
  use strict arg time,displacement,velocity,acceleration,context,evidence=.nil,derivation=.nil
  self~init:super(context,evidence,derivation)
  _time=time
  if displacement~isA(.MathVector) then _x=displacement; else _x=.MathVector~new(displacement,context)
  if velocity~isA(.MathVector) then _v=velocity; else _v=.MathVector~new(velocity,context)
  if acceleration~isA(.MathVector) then _a=acceleration; else _a=.MathVector~new(acceleration,context)
::method time; expose _time; return _time
::method displacement; expose _x; return _x
::method velocity; expose _v; return _v
::method acceleration; expose _a; return _a
::method maxAbsDifference
  expose _time _x _v _a
  use strict arg other
  d0=(_time-other~time)~abs
  d1=rx_math_vector_max_abs_difference(_x,other~displacement)
  d2=rx_math_vector_max_abs_difference(_v,other~velocity)
  d3=rx_math_vector_max_abs_difference(_a,other~acceleration)
  return max(d0,max(d1,max(d2,d3)))
::method canonical
  expose _time _x _v _a
  return 'second-order-state[t='_time';x={'_x~canonical'};v={'_v~canonical'};a={'_a~canonical'}]'
::method string; return self~canonical

::class MathSecondOrderTrajectory subclass MathValue public
::method init
  expose _times _x _v _a _dt _start _steps
  use strict arg times,displacements,velocities,accelerations,dt,startTime,context,evidence=.nil,derivation=.nil
  self~init:super(context,evidence,derivation)
  if times~isA(.MathVector) then _times=times; else _times=.MathVector~new(times,context)
  if displacements~isA(.MathMatrix) then _x=displacements; else _x=.MathMatrix~new(displacements,context,evidence)
  if velocities~isA(.MathMatrix) then _v=velocities; else _v=.MathMatrix~new(velocities,context,evidence)
  if accelerations~isA(.MathMatrix) then _a=accelerations; else _a=.MathMatrix~new(accelerations,context,evidence)
  if _x~rows<>_v~rows | _x~rows<>_a~rows | _x~cols<>_v~cols | _x~cols<>_a~cols then raise syntax 88.900 array('matching displacement/velocity/acceleration trajectory shapes')
  if _times~size<>_x~rows then raise syntax 88.900 array('one trajectory time per state row')
  _dt=dt; _start=startTime; _steps=_x~rows-1
::method times; expose _times; return _times
::method displacements; expose _x; return _x
::method velocities; expose _v; return _v
::method accelerations; expose _a; return _a
::method stepCount; expose _steps; return _steps
::method dimension; expose _x; return _x~cols
::method dt; expose _dt; return _dt
::method startTime; expose _start; return _start
::method state
  expose _times _x _v _a _steps
  use strict arg stepIndex
  if \datatype(stepIndex,'W') | stepIndex<0 | stepIndex>_steps then raise syntax 88.900 array('trajectory step index 0..'_steps,stepIndex)
  row=stepIndex+1; ctx=self~context
  return .MathSecondOrderState~new(_times[row],rx_math_matrix_row_array(_x,row),rx_math_matrix_row_array(_v,row),rx_math_matrix_row_array(_a,row),ctx,self~evidence)
::method initialState; return self~state(0)
::method finalState; expose _steps; return self~state(_steps)
::method maxAbsDifference
  expose _times _x _v _a
  use strict arg other
  if self~stepCount<>other~stepCount | self~dimension<>other~dimension then return 'INF'
  d1=_times~context~verificationContext~absoluteTolerance
  d1=rx_math_vector_max_abs_difference(_times,other~times)
  d2=_x~maxAbsDifference(other~displacements)
  d3=_v~maxAbsDifference(other~velocities)
  d4=_a~maxAbsDifference(other~accelerations)
  return max(d1,max(d2,max(d3,d4)))
::method canonical
  expose _dt _start _steps
  f=self~finalState
  return 'second-order-trajectory[steps='_steps';dt='_dt';t0='_start';final={'f~canonical'}]'
::method string; return self~canonical

::routine rx_math_matrix_row_array public
  use strict arg matrix,row
  out=.array~new
  do j=1 to matrix~cols; out~append(matrix[row,j]); end
  return out

::routine rx_math_second_order_force_history public
  use strict arg forces,steps,dimension,context
  rows=.array~new
  if forces==.nil then do
    do i=0 to steps
      row=.array~new; do j=1 to dimension; row~append(rx_math_zero(context)); end; rows~append(row)
    end
    return .MathMatrix~new(rows,context)
  end
  if forces~isA(.MathVector) then do
    if forces~size<>dimension then raise syntax 88.900 array('constant force vector matching system dimension',dimension)
    do i=0 to steps; rows~append(forces~toArray); end
    return .MathMatrix~new(rows,context)
  end
  if forces~isA(.MathMatrix) then do
    if forces~rows<>steps+1 | forces~cols<>dimension then raise syntax 88.900 array('force-history matrix shape '(steps+1)'x'dimension,forces~rows'x'forces~cols)
    return .MathMatrix~new(forces~toArray,context)
  end
  if forces~isA(.array) then do
    if forces~items=dimension then return rx_math_second_order_force_history(.MathVector~new(forces,context),steps,dimension,context)
    return rx_math_second_order_force_history(.MathMatrix~new(forces,context),steps,dimension,context)
  end
  raise syntax 88.900 array('nil, MathVector, MathMatrix or Array force history',forces~class~id)

::routine rx_math_second_order_integrate public
  use strict arg provider,system,initialDisplacement,initialVelocity,dt,steps,forces,startTime,method,context,evidenceProvider='PURE'
  numeric digits context~workingDigits+16
  sys=system~withContext(context); n=sys~dimension
  x=.MathVector~new(initialDisplacement~toArray,context); v=.MathVector~new(initialVelocity~toArray,context)
  fh=rx_math_second_order_force_history(forces,steps,n,context)
  m=sys~massMatrix; c=sys~dampingMatrix; k=sys~stiffnessMatrix
  h=rx_math_coerce_value(dt,context); one=rx_math_coerce_value(1,context); two=rx_math_coerce_value(2,context); method=method~upper
  times=.array~new; xs=.array~new; vs=.array~new; accs=.array~new
  f0=.MathVector~new(rx_math_matrix_row_array(fh,1),context)
  cv=provider~matrixMul(c,v,context); kx=provider~matrixMul(k,x,context)
  rhs0=provider~vectorSub(provider~vectorSub(f0,cv,context),kx,context)
  a=provider~matrixSolve(m,rhs0,context)
  times~append(rx_math_coerce_value(startTime,context)); xs~append(x~toArray); vs~append(v~toArray); accs~append(a~toArray)
  if method='SYMPLECTIC_EULER' then do
    do step=1 to steps
      fn=.MathVector~new(rx_math_matrix_row_array(fh,step),context)
      cv=provider~matrixMul(c,v,context); kx=provider~matrixMul(k,x,context)
      rhs=provider~vectorSub(provider~vectorSub(fn,cv,context),kx,context)
      aStep=provider~matrixSolve(m,rhs,context)
      vn=provider~vectorAdd(v,provider~vectorMul(aStep,h,context),context)
      xn=provider~vectorAdd(x,provider~vectorMul(vn,h,context),context)
      fn1=.MathVector~new(rx_math_matrix_row_array(fh,step+1),context)
      cv1=provider~matrixMul(c,vn,context); kx1=provider~matrixMul(k,xn,context)
      an=provider~matrixSolve(m,provider~vectorSub(provider~vectorSub(fn1,cv1,context),kx1,context),context)
      x=xn; v=vn; a=an
      times~append(rx_math_coerce_value(startTime,context)+h*step); xs~append(x~toArray); vs~append(v~toArray); accs~append(a~toArray)
    end
    algorithm=evidenceProvider~lower'-symplectic-euler + provider-linear-solve'
  end
  else do
    beta=rx_math_coerce_value('0.25',context); gamma=rx_math_coerce_value('0.5',context)
    a0c=one/(beta*h*h); a1c=gamma/(beta*h); a2c=one/(beta*h); a3c=one/(beta*two)-one; a4c=gamma/beta-one; a5c=h*(gamma/(beta*two)-one)
    meff=provider~matrixMul(m,a0c,context); ceff=provider~matrixMul(c,a1c,context)
    keff=provider~matrixAdd(provider~matrixAdd(k,meff,context),ceff,context)
    do step=1 to steps
      tx=provider~vectorAdd(provider~vectorAdd(provider~vectorMul(x,a0c,context),provider~vectorMul(v,a2c,context),context),provider~vectorMul(a,a3c,context),context)
      tc=provider~vectorAdd(provider~vectorAdd(provider~vectorMul(x,a1c,context),provider~vectorMul(v,a4c,context),context),provider~vectorMul(a,a5c,context),context)
      fn=.MathVector~new(rx_math_matrix_row_array(fh,step+1),context)
      rhs=provider~vectorAdd(fn,provider~vectorAdd(provider~matrixMul(m,tx,context),provider~matrixMul(c,tc,context),context),context)
      xn=provider~matrixSolve(keff,rhs,context)
      an=provider~vectorSub(provider~vectorSub(provider~vectorMul(provider~vectorSub(xn,x,context),a0c,context),provider~vectorMul(v,a2c,context),context),provider~vectorMul(a,a3c,context),context)
      vn=provider~vectorAdd(v,provider~vectorMul(provider~vectorAdd(provider~vectorMul(a,one-gamma,context),provider~vectorMul(an,gamma,context),context),h,context),context)
      x=xn; v=vn; a=an
      times~append(rx_math_coerce_value(startTime,context)+h*step); xs~append(x~toArray); vs~append(v~toArray); accs~append(a~toArray)
    end
    algorithm=evidenceProvider~lower'-newmark-average-acceleration + provider-linear-solve'
  end
  ev=.MathEvidence~new('dynamics.second-order.integrate',context,.array~of(system~canonical,'dt='dt,'steps='steps,'t0='startTime))
  guarantee='APPROXIMATE'; if context~numberDomain='RATIONAL' then guarantee='EXACT_DISCRETE_INTEGRATOR'
  if method='SYMPLECTIC_EULER' then methodTag='SYMPLECTIC-EULER'; else methodTag='NEWMARK'
  tags=evidenceProvider',SECOND-ORDER,LINEAR-SYSTEM,'methodTag
  ev~addStep(.MathPathStep~new('dynamics.second-order.integrate',evidenceProvider,provider~version,algorithm,context~numberDomain,context~workingDigits,'MathSecondOrderTrajectory','Constant M,C,K; explicit integrator='method'.',guarantee,tags','method))
  deriv=.MathDerivation~new('dynamics.second-order.integrate',.array~of(system,initialDisplacement,initialVelocity,dt,steps,forces,startTime),method)
  return .MathSecondOrderTrajectory~new(times,xs,vs,accs,dt,startTime,context,ev,deriv)

/* ---------- high-precision helpers ---------- */

::routine rx_math_scalar_kernel public
  use strict arg operation,value,context
  op=operation~upper
  select
    when op='SQRT' then return rx_math_numeric_sqrt(value,context)
    when op='SIN' then return rx_math_numeric_sin(value,context)
    when op='COS' then return rx_math_numeric_cos(value,context)
    when op='TAN' then do
      c=rx_math_numeric_cos(value,context)
      if rx_math3d_near_zero(c,context) then raise syntax 42.3
      numeric digits context~workingDigits+12
      return rx_math_numeric_sin(value,context)/c
    end
    when op='EXP' then return rx_math_numeric_exp(value,context)
    when op='LN' | op='LOG' then return rx_math_numeric_ln(value,context)
    when op='LOG10' then do
      numeric digits context~workingDigits+24
      return rx_math_numeric_ln(value,context)/rx_math_numeric_ln(10,context)
    end
    when op='ATAN' then return rx_math_numeric_atan(value,context)
    when op='ATAN2' then do
      if \value~isA(.array) then raise syntax 88.900 array('ATAN2 input array [y,x]',value)
      if value~items<>2 then raise syntax 88.900 array('ATAN2 input array [y,x]',value)
      return rx_math_numeric_atan2(value[1],value[2],context)
    end
    otherwise raise syntax 88.900 array('supported scalar operation',operation)
  end

::routine rx_math_numeric_scalar public
  use strict arg value,context
  numeric digits context~workingDigits+20
  if context~numberDomain='RATIONAL' then return .MathRational~coerce(value,context)
  if value~isA(.MathRational) then return value~toDecimal(context~workingDigits+20)
  if value~isA(.MathScalarResult) then return rx_math_numeric_scalar(value~value,context)
  return value

::routine rx_math_resolve_constant_name public
  use strict arg name
  keyName=name~string~strip~upper
  select
    when keyName='0' | keyName='ZERO' | keyName='ADDITIVEIDENTITY' then return 'ZERO'
    when keyName='1' | keyName='ONE' | keyName='MULTIPLICATIVEIDENTITY' then return 'ONE'
    when keyName='I' | keyName='IMAGINARYUNIT' | keyName='IMAGINARY_UNIT' then return 'IMAGINARYUNIT'
    when keyName='PI' then return 'PI'
    when keyName='TAU' | keyName='2PI' | keyName='TWO_PI' then return 'TAU'
    when keyName='E' | keyName='EULER' | keyName='EULERNUMBER' | keyName='EULER_NUMBER' then return 'E'
    when keyName='EULERMASCHERONI' | keyName='EULER_MASCHERONI' | keyName='GAMMA0' | keyName='GAMMA_0' then return 'EULERMASCHERONI'
    when keyName='GOLDENRATIO' | keyName='GOLDEN_RATIO' | keyName='PHI' then return 'GOLDENRATIO'
    when keyName='SQRT2' | keyName='SQRT_2' | keyName='PYTHAGORAS' | keyName='PYTHAGORASCONSTANT' then return 'SQRT2'
    otherwise return ''
  end

::routine rx_math_constant_names public
  return .array~of('ZERO','ONE','IMAGINARYUNIT','PI','TAU','E','EULERMASCHERONI','GOLDENRATIO','SQRT2')

::routine rx_math_constant_info public
  use strict arg name
  canonical=rx_math_resolve_constant_name(name)
  if canonical='' then raise syntax 88.900 array('published named mathematical constant',name)
  d=.directory~new
  d['name']=canonical
  d['cachePolicy']='CONTEXT'
  d['provenance']='oorexx_maths constant registry v1'
  select
    when canonical='ZERO' then do
      d['aliases']='0, ZERO, ADDITIVEIDENTITY'; d['category']='FUNDAMENTAL'; d['kind']='EXACT_STRUCTURAL'
      d['computability']='EXACT'; d['definition']='additive identity'; d['precisionCapability']='UNBOUNDED_EXACT'; d['numberDomains']='DECIMAL,BINARY64,RATIONAL'
    end
    when canonical='ONE' then do
      d['aliases']='1, ONE, MULTIPLICATIVEIDENTITY'; d['category']='FUNDAMENTAL'; d['kind']='EXACT_STRUCTURAL'
      d['computability']='EXACT'; d['definition']='multiplicative identity'; d['precisionCapability']='UNBOUNDED_EXACT'; d['numberDomains']='DECIMAL,BINARY64,RATIONAL'
    end
    when canonical='IMAGINARYUNIT' then do
      d['aliases']='I, IMAGINARYUNIT'; d['category']='FUNDAMENTAL'; d['kind']='EXACT_COMPLEX'
      d['computability']='EXACT'; d['definition']='i^2 = -1'; d['precisionCapability']='UNBOUNDED_EXACT'; d['numberDomains']='DECIMAL,BINARY64,RATIONAL'
    end
    when canonical='PI' then do
      d['aliases']='PI'; d['category']='TRANSCENDENTAL'; d['kind']='COMPUTABLE_TRANSCENDENTAL'
      d['computability']='COMPUTABLE'; d['definition']='circle circumference / diameter'; d['precisionCapability']='CONTEXT_DRIVEN'; d['numberDomains']='DECIMAL,BINARY64'
    end
    when canonical='TAU' then do
      d['aliases']='TAU, 2PI'; d['category']='GEOMETRIC'; d['kind']='EXACT_DERIVATION'
      d['computability']='COMPUTABLE'; d['definition']='2 * pi'; d['precisionCapability']='CONTEXT_DRIVEN'; d['numberDomains']='DECIMAL,BINARY64'
    end
    when canonical='E' then do
      d['aliases']='E, EULERNUMBER'; d['category']='TRANSCENDENTAL'; d['kind']='COMPUTABLE_TRANSCENDENTAL'
      d['computability']='COMPUTABLE'; d['definition']='exp(1)'; d['precisionCapability']='CONTEXT_DRIVEN'; d['numberDomains']='DECIMAL,BINARY64'
    end
    when canonical='EULERMASCHERONI' then do
      d['aliases']='EULERMASCHERONI, GAMMA0'; d['category']='ANALYSIS'; d['kind']='COMPUTABLE_TRANSCENDENTAL'
      d['computability']='COMPUTABLE'; d['definition']='lim(H_n - ln(n))'; d['precisionCapability']='250_DIGIT_SEED'; d['numberDomains']='DECIMAL,BINARY64'
    end
    when canonical='GOLDENRATIO' then do
      d['aliases']='GOLDENRATIO, PHI'; d['category']='ALGEBRAIC'; d['kind']='EXACT_DERIVATION'
      d['computability']='ALGEBRAIC'; d['definition']='(1 + sqrt(5)) / 2'; d['precisionCapability']='CONTEXT_DRIVEN'; d['numberDomains']='DECIMAL,BINARY64'
    end
    when canonical='SQRT2' then do
      d['aliases']='SQRT2, PYTHAGORAS'; d['category']='ALGEBRAIC'; d['kind']='EXACT_DERIVATION'
      d['computability']='ALGEBRAIC'; d['definition']='positive root of x^2 - 2'; d['precisionCapability']='CONTEXT_DRIVEN'; d['numberDomains']='DECIMAL,BINARY64'
    end
  end
  return d

::routine rx_math_named_constant public
  use strict arg name,context
  canonical=rx_math_resolve_constant_name(name)
  if canonical='' then raise syntax 88.900 array('supported named mathematical constant',name)
  cache=.local['OOREXX_MATHS_CONSTANT_CACHE']
  cacheKey=canonical'|'context~numberDomain'|'context~workingDigits
  if cache~hasIndex(cacheKey) then return cache[cacheKey]

  if canonical='ZERO' then do
    if context~numberDomain='RATIONAL' then value=.MathInteger~new(0,context); else value=0
  end
  else if canonical='ONE' then do
    if context~numberDomain='RATIONAL' then value=.MathInteger~new(1,context); else value=1
  end
  else if canonical='IMAGINARYUNIT' then value=.MathComplex~new(0,1,context)
  else do
    if context~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for irrational/transcendental named constant',canonical)
    numeric digits context~workingDigits+20
    select
      when canonical='PI' then value=rx_math_numeric_pi_uncached(context)
      when canonical='TAU' then value=2*rx_math_named_constant('PI',context)
      when canonical='E' then value=rx_math_numeric_exp(1,context)
      when canonical='EULERMASCHERONI' then value=rx_math_numeric_euler_mascheroni(context)
      when canonical='GOLDENRATIO' then value=(1+rx_math_numeric_sqrt(5,context))/2
      when canonical='SQRT2' then value=rx_math_numeric_sqrt(2,context)
      otherwise raise syntax 88.900 array('implemented named mathematical constant',canonical)
    end
  end
  cache[cacheKey]=value
  return value

::routine rx_math_numeric_pi public
  use strict arg context
  return rx_math_named_constant('PI',context)

::routine rx_math_numeric_pi_uncached
  use strict arg context
  if context~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for pi','RATIONAL')
  numeric digits context~workingDigits+20
  return format(rx_math3d_pi(context))

::routine rx_math_numeric_euler_mascheroni
  use strict arg context
  if context~workingDigits>250 then raise syntax 88.900 array('Euler-Mascheroni context working precision <= 250 digits',context~workingDigits)
  numeric digits context~workingDigits
  seed='0.57721566490153286060651209008240243104215933593992359880576723488486772677766467093694706329174674951463144724980708248096050401448654283622417399764492353625350033374293733773767394279259525824709491600873520394816567085323315177661152862119950150798479374509'
  return format(seed)

::routine rx_math_numeric_sqrt public
  use strict arg value,context
  return rx_math3d_sqrt(value,context)

::routine rx_math_numeric_sin public
  use strict arg value,context
  return rx_math3d_sin(rx_math_numeric_scalar(value,context),context)

::routine rx_math_numeric_cos public
  use strict arg value,context
  return rx_math3d_cos(rx_math_numeric_scalar(value,context),context)

::routine rx_math_numeric_exp public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then do
    r=.MathRational~coerce(value,context)
    if r=0 then return .MathInteger~new(1,context)
    raise syntax 88.900 array('DECIMAL/BINARY context for non-trivial exponential',r~string)
  end
  work=context~workingDigits+32; if work<80 then work=80
  numeric digits work
  x=rx_math_numeric_scalar(value,context)
  if x=0 then return 1
  negative=(x<0); if negative then x=-x
  halves=0
  do while x>'0.125'
    x=x/2; halves+=1
    if halves>4096 then raise syntax 88.900 array('exponential argument within supported range-reduction budget',value)
  end
  term=1; sum=1; n=1; limit='1E-'||(context~workingDigits+14)
  do while term~abs>limit
    term=term*x/n; sum=sum+term; n+=1
    if n>10000 then raise syntax 88.900 array('convergent exponential series',value)
  end
  do i=1 to halves; sum=sum*sum; end
  if negative then sum=1/sum
  return sum

::routine rx_math_numeric_ln public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then do
    r=.MathRational~coerce(value,context)
    if r=1 then return .MathInteger~new(0,context)
    raise syntax 88.900 array('DECIMAL/BINARY context for non-trivial natural logarithm',r~string)
  end
  work=context~workingDigits+32; if work<80 then work=80
  numeric digits work
  x=rx_math_numeric_scalar(value,context)
  if x<=0 then raise syntax 88.900 array('positive natural-logarithm input',value)
  /* Range-reduce to [0.75,1.5], then use ln(x)=2*atanh((x-1)/(x+1)). */
  twos=0
  do while x>'1.5'
    x=x/2; twos+=1
    if twos>100000 then raise syntax 88.900 array('logarithm argument within range-reduction budget',value)
  end
  do while x<'0.75'
    x=x*2; twos-=1
    if twos< -100000 then raise syntax 88.900 array('logarithm argument within range-reduction budget',value)
  end
  z=(x-1)/(x+1); z2=z*z; term=z; sum=z; k=1; limit='1E-'||(context~workingDigits+14)
  do while term~abs>limit
    term=term*z2; k+=2; sum=sum+term/k
    if k>20000 then raise syntax 88.900 array('convergent logarithm series',value)
  end
  ln2='0.693147180559945309417232121458176568075500134360255254120680009493393621969694715605863326996418687'
  return 2*sum+twos*ln2

::routine rx_math_numeric_atan_series public
  use strict arg x,context
  work=context~workingDigits+32; if work<80 then work=80
  numeric digits work
  x2=x*x; term=x; sum=x; k=1; sign=-1; limit='1E-'||(context~workingDigits+14)
  do while term~abs>limit
    term=term*x2; k+=2; sum=sum+sign*term/k; sign=-sign
    if k>50000 then raise syntax 88.900 array('convergent arctangent series',x)
  end
  return sum

::routine rx_math_numeric_atan public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then do
    r=.MathRational~coerce(value,context)
    if r=0 then return .MathInteger~new(0,context)
    raise syntax 88.900 array('DECIMAL/BINARY context for non-trivial arctangent',r~string)
  end
  work=context~workingDigits+32; if work<80 then work=80
  numeric digits work
  x=rx_math_numeric_scalar(value,context)
  if x=0 then return 0
  neg=(x<0); if neg then x=-x
  pi=rx_math_numeric_pi(context)
  if x>1 then do
    y=1/x
    if y>'0.5' then do
      t=(y-1)/(y+1)
      atanValue=pi/4-rx_math_numeric_atan_series(t,context)
    end
    else atanValue=pi/2-rx_math_numeric_atan_series(y,context)
  end
  else if x>'0.5' then do
    t=(x-1)/(x+1)
    atanValue=pi/4+rx_math_numeric_atan_series(t,context)
  end
  else atanValue=rx_math_numeric_atan_series(x,context)
  if neg then atanValue=-atanValue
  return atanValue

::routine rx_math_numeric_atan2 public
  use strict arg yValue,xValue,context
  work=context~workingDigits+32; if work<80 then work=80
  numeric digits work
  y=rx_math_numeric_scalar(yValue,context); x=rx_math_numeric_scalar(xValue,context)
  if context~numberDomain='RATIONAL' then do
    if y=0 then if x>0 then return .MathInteger~new(0,context)
    raise syntax 88.900 array('DECIMAL/BINARY context for non-trivial atan2',y x)
  end
  pi=rx_math_numeric_pi(context)
  if x>0 then return rx_math_numeric_atan(y/x,context)
  if x<0 then if y>=0 then return rx_math_numeric_atan(y/x,context)+pi
  if x<0 then if y<0 then return rx_math_numeric_atan(y/x,context)-pi
  if x=0 then if y>0 then return pi/2
  if x=0 then if y<0 then return -pi/2
  raise syntax 88.900 array('atan2 undefined for x=0,y=0',y x)

::routine rx_math3d_scalar public
  use strict arg value,context
  numeric digits context~workingDigits
  if context~numberDomain='RATIONAL' then return .MathRational~coerce(value,context)
  if value~isA(.MathRational) then return value~toDecimal(context~workingDigits)
  return value

::routine rx_math3d_pi public
  use strict arg context
  /* 240+ decimal digits; callers fail closed if a reduction would require more. */
  return '3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628034825342117067982148086513282306647093844609550582231725359408128481117450284102701938521105559644622948954930381964428810975665933446128475648233'

::routine rx_math3d_reduce_work_digits public
  use strict arg value,context
  s=value~string~strip~upper; mag=1
  ep=s~pos('E')
  if ep>0 then do
    exp=s~substr(ep+1)
    exponentIsInteger=datatype(exp,'W')
    if \exponentIsInteger then do
      if left(exp,1)='-' then exponentIsInteger=datatype(substr(exp,2),'W')
      else if left(exp,1)='+' then exponentIsInteger=datatype(substr(exp,2),'W')
    end
    if exponentIsInteger then mag=abs(exp)+context~workingDigits
  end
  else do
    dot=s~pos('.'); if dot=0 then dot=length(s)+1
    mag=dot-1; if left(s,1)='-' | left(s,1)='+' then mag=mag-1
    if mag<1 then mag=1
  end
  work=context~workingDigits+mag+24
  if work>220 then raise syntax 88.900 array('angle magnitude reducible with bundled pi precision (<=220 working digits)',s)
  return work

::routine rx_math3d_reduce_degrees public
  use strict arg value,context
  if value~isA(.MathRational) then do
    n=value~numerator; d=value~denominator
    work=rx_math_integer_work_digits(n,d)+16; numeric digits work
    period=360*d; rem=n//period
    r=.MathRational~of(rem,d,context)
    if r>=180 then r=r-360
    if r< -180 then r=r+360
    return r
  end
  work=rx_math3d_reduce_work_digits(value,context); numeric digits work
  r=value//360
  if r>=180 then r=r-360
  if r< -180 then r=r+360
  return r

::routine rx_math3d_reduce_radians public
  use strict arg value,context
  work=rx_math3d_reduce_work_digits(value,context); numeric digits work
  pi=rx_math3d_pi(context); tau=2*pi
  r=value//tau
  if r>pi then r=r-tau
  if r< -pi then r=r+tau
  return r

::routine rx_math3d_sin public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for sine',value)
  work=context~workingDigits+30; if work<80 then work=80
  numeric digits work
  x=rx_math3d_reduce_radians(value,context); pi=rx_math3d_pi(context); sign=1
  if x>pi/2 then x=pi-x
  else if x< -pi/2 then x=-pi-x
  term=x; sum=x; n=1; limit='1E-'||(context~workingDigits+12)
  do while term~abs>limit & n<1000
    term=-term*x*x/((2*n)*(2*n+1)); sum=sum+term; n=n+1
  end
  if n>=1000 then raise syntax 88.900 array('convergent sine series',value)
  return sum

::routine rx_math3d_cos public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then raise syntax 88.900 array('DECIMAL/BINARY context for cosine',value)
  work=context~workingDigits+30; if work<80 then work=80
  numeric digits work
  x=rx_math3d_reduce_radians(value,context); pi=rx_math3d_pi(context); sign=1
  if x>pi/2 then do; x=pi-x; sign=-1; end
  else if x< -pi/2 then do; x=-pi-x; sign=-1; end
  term=1; sum=1; n=1; limit='1E-'||(context~workingDigits+12)
  do while term~abs>limit & n<1000
    term=-term*x*x/((2*n-1)*(2*n)); sum=sum+term; n=n+1
  end
  if n>=1000 then raise syntax 88.900 array('convergent cosine series',value)
  return sign*sum

::routine rx_math3d_sqrt public
  use strict arg value,context
  if context~numberDomain='RATIONAL' then do
    r=.MathRational~coerce(value,context)
    if r~numerator<0 then raise syntax 88.900 array('non-negative square-root input',value)
    rn=rx_math3d_integer_sqrt_exact(r~numerator)
    rd=rx_math3d_integer_sqrt_exact(r~denominator)
    if rn==.nil | rd==.nil then raise syntax 88.900 array('exact rational perfect-square root or DECIMAL/BINARY context',r~string)
    return .MathRational~of(rn,rd,context)
  end
  work=context~workingDigits+30; if work<80 then work=80
  numeric digits work
  if value~isA(.MathRational) then x=value~toDecimal(work); else x=value
  if x<0 then raise syntax 88.900 array('non-negative square-root input',value)
  if x=0 then return 0
  guess=1
  s=x~string~upper; ep=s~pos('E')
  if ep>0 then do
    e=s~substr(ep+1); half=e%2; guess=10**half
  end
  else if x>1 then guess=x/2
  limit='1E-'||(context~workingDigits+10); i=0
  do forever
    next=(guess+x/guess)/2; i=i+1
    if (next-guess)~abs<=limit then return next
    guess=next
    if i>1000 then raise syntax 88.900 array('convergent Newton square root',value)
  end

::routine rx_math3d_integer_sqrt_exact public
  use strict arg value
  text=value~string~strip
  if left(text,1)='-' then return .nil
  work=length(text)+16; if work<32 then work=32
  numeric digits work
  n=text
  if n=0 | n=1 then return n
  x=n; y=(x+1)%2
  do while y<x
    x=y; y=(x+n%x)%2
  end
  if x*x=n then return x
  return .nil

::routine rx_math3d_near_zero public
  use strict arg value,context
  numeric digits context~workingDigits+10
  if context~numberDomain='RATIONAL' then return value=0
  return value~abs <= context~absoluteTolerance

::routine rx_math3d_evidence public
  use strict arg operation,context,inputs,algorithm,details,guarantee='APPROXIMATE_HIGH_PRECISION'
  ev=.MathEvidence~new(operation,context,inputs)
  ev~addStep(.MathPathStep~new(operation,'PURE','0.12',algorithm,context~numberDomain,context~workingDigits,'Maths 3D semantic object',details,guarantee,'PURE,MATH3D,'algorithm))
  return ev
