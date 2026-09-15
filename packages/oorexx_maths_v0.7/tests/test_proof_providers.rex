numeric digits 50
failures=0
ctx=.MathContext~decimal(50)
call check .Maths~provider('SYMPY') \== .nil,'SymPy proof provider registered'
call check .Maths~provider('MPMATH-IV') \== .nil,'mpmath interval provider registered'

x=.Maths~variable('x',ctx)
expr=(x*2)-(x*2)
p=expr~prove(.MathClaim~equals(0))
call check p~outcome='PROVED','SymPy independently proves dependency identity'
call check p~status='SYMBOLICALLY_PROVED','SymPy proof strength is symbolic'
call check p~primaryEvidence~primaryProvider='SYMPY','symbolic proof records provider'
call check p~primaryEvidence~steps[1]~guarantee='EXACT_IF_SYMBOLIC_ZERO','symbolic path records exact-zero proof scope'
call check p~checks['simplifiedDifference']='0','symbolic proof records reduced difference'

bounds=.directory~new; bounds['x']=.array~of('0','1')
iv=expr~interval(bounds,ctx)
call check iv~lower='-2.0' & iv~upper='2.0','mpmath interval shows dependency over-enclosure [-2,2]'
call check iv~width='4.0','interval width exposes weak bound'
call check iv~evidence~primaryProvider='MPMATH-IV','interval evidence records provider'
call check iv~evidence~steps[1]~guarantee='RIGOROUS_CONTAINMENT_FOR_SUPPORTED_DIRECT_ARITHMETIC','interval path declares precise containment guarantee'
call check iv~evidence~warnings~items>=1,'interval evidence warns that containment may be weak'
ip=iv~prove
call check ip~outcome='PROVED' & ip~status='INTERVAL_CERTIFIED','interval provider certifies its precise containment claim'
call check ip~claim~kind='ENCLOSES_EXACT_EVALUATION','interval proof retains containment claim scope'

/* Same proposition, two evidence paths: interval is valid-but-weak, symbolic is exact. */
call check p~outcome='PROVED' & iv~width<>0,'stronger symbolic claim coexists with weak interval enclosure'

dec=.Maths~constant('0.1',ctx)+.Maths~constant('0.2',ctx)
dp=dec~prove(.MathClaim~equals('0.3'))
call check dp~outcome='PROVED','SymPy treats decimal source literals exactly rather than importing binary float error'
empty=.directory~new; div=dec~interval(empty,ctx)
call check div~lower<=0.3 & div~upper>=0.3,'mpmath interval decimal literal path encloses exact decimal 0.3'

if failures=0 then do; say 'PASS oorexx_maths proof providers 17 assertions'; exit 0; end
say 'FAIL oorexx_maths proof providers failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathProofProviders.cls'
