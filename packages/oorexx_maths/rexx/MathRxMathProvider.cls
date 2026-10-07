/* Optional native scalar provider using the ooRexx distribution RxMath C library.
 * This provider is deliberately BINARY64/16-digit only.  It never silently
 * narrows DECIMAL or RATIONAL contexts.  Proof/replay is handled by Maths' independent
 * REFERENCE provider at increased decimal precision.
 */
ignored=.Maths~registerProvider(.MathRxMathProvider~new)

::class MathRxMathProvider subclass MathProvider public
::method name; return 'RXMATH'
::method version; return 'ooRexx-distribution-RxMath'
::method supports
  use strict arg operation
  op=operation~lower
  return op='scalar.sqrt' | op='scalar.sin' | op='scalar.cos' | op='scalar.tan' | -
         op='scalar.exp' | op='scalar.ln' | op='scalar.log' | op='scalar.log10' | -
         op='scalar.atan' | op='scalar.atan2'

::method scalarCompute
  use strict arg operation,value,context
  if context~numberDomain<>'BINARY64' then raise syntax 88.900 array('BINARY64 MathContext for RXMATH native scalar provider',context~canonical)
  op=operation~upper
  numeric digits 18
  if op='ATAN2' then do
    if \value~isA(.array) then raise syntax 88.900 array('ATAN2 input array [y,x]',value)
    if value~items<>2 then raise syntax 88.900 array('ATAN2 input array [y,x]',value)
    y=value[1]; x=value[2]
    answer=self~atan2Native(y,x)
    inputs=.array~of(y,x)
    symbol='RxCalcArcTan + RxCalcPi quadrant composition'
  end
  else do
    x=value; inputs=.array~of(x)
    select
      when op='SQRT' then do
        if x<0 then raise syntax 42.3
        answer=rxm_sqrt(x,16); symbol='RxCalcSqrt'
      end
      when op='SIN' then do; answer=rxm_sin(x,16,'R'); symbol='RxCalcSin'; end
      when op='COS' then do; answer=rxm_cos(x,16,'R'); symbol='RxCalcCos'; end
      when op='TAN' then do; answer=rxm_tan(x,16,'R'); symbol='RxCalcTan'; end
      when op='EXP' then do; answer=rxm_exp(x,16); symbol='RxCalcExp'; end
      when op='LN' | op='LOG' then do
        if x<=0 then raise syntax 42.3
        answer=rxm_log(x,16); symbol='RxCalcLog'
      end
      when op='LOG10' then do
        if x<=0 then raise syntax 42.3
        answer=rxm_log10(x,16); symbol='RxCalcLog10'
      end
      when op='ATAN' then do; answer=rxm_atan(x,16,'R'); symbol='RxCalcArcTan'; end
      otherwise raise syntax 88.900 array('RXMATH-supported scalar operation',operation)
    end
  end
  low=op~lower
  ev=.MathEvidence~new('scalar.'low,context,inputs)
  details='Native ooRexx distribution librxmath external routine 'symbol'; precision parameter=16; caller explicitly selected BINARY64.'
  ignored=ev~addStep(.MathPathStep~new('scalar.'low,self~name,self~version,'native-rxmath-'low,'BINARY64',16,'RxMath C double result',details,'APPROXIMATE_16_DIGIT_NATIVE','RXMATH,NATIVE,C-DOUBLE,'symbol))
  ev~addWarning('RxMath is limited to approximately 16 decimal digits.  The provider is accepted only for explicit BINARY64 context; higher-precision verification uses a different Maths provider.')
  deriv=.MathDerivation~new('scalar.'low,inputs)
  return .MathScalarResult~new(answer,op,context,ev,deriv)

::method atan2Native private
  use strict arg y,x
  numeric digits 18
  pi=rxm_pi(16)
  if x>0 then return rxm_atan(y/x,16,'R')
  if x<0 then do
    a=rxm_atan(y/x,16,'R')
    if y>=0 then return a+pi
    return a-pi
  end
  if y>0 then return pi/2
  if y<0 then return -pi/2
  return 0

::routine rxm_sqrt  external "library rxmath RxCalcSqrt"
::routine rxm_sin   external "library rxmath RxCalcSin"
::routine rxm_cos   external "library rxmath RxCalcCos"
::routine rxm_tan   external "library rxmath RxCalcTan"
::routine rxm_exp   external "library rxmath RxCalcExp"
::routine rxm_log   external "library rxmath RxCalcLog"
::routine rxm_log10 external "library rxmath RxCalcLog10"
::routine rxm_atan  external "library rxmath RxCalcArcTan"
::routine rxm_pi    external "library rxmath RxCalcPi"

::requires 'MathsBootstrap.cls'
