numeric digits 50
failures=0
ctx=.MathContext~decimal(50)

a=.Maths~rational(2,4,ctx)
call check a~string='1/2','rational normalizes by exact gcd'
call check .Maths~rational(1,-2,ctx)~string='-1/2','rational normalizes denominator sign'
b=.Maths~rational(1,3,ctx)
c=.Maths~rational(1,6,ctx)
call check (b+c)~string='1/2','rational overloaded + is exact'
call check (b-c)~string='1/6','rational overloaded - is exact'
call check (b*c)~string='1/18','rational overloaded * is exact'
call check (b/c)~string='2','rational overloaded / is exact'
call check (b**-2)~string='9','rational overloaded ** supports negative integer powers'
call check .Maths~rationalFromDecimal('0.125',ctx)~string='1/8','finite decimal is converted to exact rational'
call check .Maths~rationalFromDecimal('1.25E-3',ctx)~string='1/800','scientific decimal is converted exactly'

huge=.Maths~rational('123456789012345678901234567890123456789012345678901234567891',7,ctx)
half=.Maths~rational(1,2,ctx)
h=huge*half
call check h~numerator='123456789012345678901234567890123456789012345678901234567891' & h~denominator=14,'rational exact path exceeds default NUMERIC DIGITS safely'

sum=b+c
call check sum~evidence~operation='rational.add','rational operation retains mathematical path rather than construction-only provenance'
p=sum~prove(.MathClaim~isExact)
call check p~outcome='PROVED' & p~status='EXACT','exact rational representation proves IS_EXACT'
eq=sum~prove(.MathClaim~equals('0.5'))
call check eq~outcome='PROVED' & eq~status='EXACT','exact rational equality accepts exact decimal claim'
ne=sum~prove(.MathClaim~equals('0.50000000000000000000000000000000000000000000000001'))
call check ne~outcome='DISPROVED','exact rational equality disproves nearby decimal without tolerance'
hugeNeg=.Maths~rational('-123456789012345678901234567890123456789012345678901234567890123456789',7,ctx)
hugeAbs=hugeNeg~abs
call check hugeAbs~numerator='123456789012345678901234567890123456789012345678901234567890123456789','rational abs preserves huge exact integer beyond caller NUMERIC DIGITS'

if failures=0 then do; say 'PASS oorexx_maths rational 15 assertions'; exit 0; end
say 'FAIL oorexx_maths rational failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label; return
::requires 'MathsBootstrap.cls'
