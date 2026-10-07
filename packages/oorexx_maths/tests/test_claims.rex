numeric digits 50
failures=0
ctx=.MathContext~decimal(50)

x=.Maths~variable('x',ctx)
expr=(x*2)-(x*2)
call check expr~simplify~providerText='0','structural dependency cancellation simplifies exactly'
claim=.MathClaim~equals(0)
p=expr~prove(claim)
call check p~outcome='PROVED','explicit equality claim is proved'
call check p~status='EXACT','local structural proof has exact strength'
call check p~claim~kind='EQUALS','proof retains claim'
ass=.Maths~assumptions; ass~real(x); ass~positive(x)
pa=expr~prove(claim,ass)
call check pa~assumptions~has(x,'POSITIVE'),'proof retains explicit mathematical assumptions'

S=.Maths~matrix(.array~of(.array~of(3,2),.array~of(1,2)),ctx)
b=.Maths~vector(.array~of(5,5),ctx)
sol=S~solve(b)
q=sol~prove(.MathClaim~satisfiesEquation('1E-45'))
call check q~outcome='PROVED','equation residual claim proved within explicit tolerance'
call check q~status='NUMERICALLY_SATISFIED','equation claim strength is numerical not exact'
call check q~checks['residualInf'] <= 1E-45,'equation proof exposes residual'

accuracy=sol~prove(.MathClaim~accurateDigits(40))
call check accuracy~outcome='INDETERMINATE','accuracy-to-N-digits is not inferred from duplicate approximation'

ind=sol~prove
call check ind~outcome='PROVED' & ind~status='VERIFIED_NUMERICALLY','legacy prove surface maps to explicit independent-reproduction claim'

if failures=0 then do; say 'PASS oorexx_maths claims 10 assertions'; exit 0; end
say 'FAIL oorexx_maths claims failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathsBootstrap.cls'
