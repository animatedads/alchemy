numeric digits 50
failures=0
ctx=.MathContext~decimal(50)

call check .MathProofPolicy~standard~name='STANDARD','standard proof policy exists'
call check .MathProofPolicy~strong~requireCorroboration,'strong proof policy requires corroboration'
call check .MathProofPolicy~certified~certifiedOnly,'certified proof policy requires certifying evidence'

S=.Maths~matrix(.array~of(.array~of(3,2),.array~of(1,2)),ctx)
b=.Maths~vector(.array~of(5,5),ctx)
x=S~solve(b)
claim=.MathClaim~satisfiesEquation('1E-45')

plan=.Maths~planProof(x,claim,.nil,'STANDARD')
call check plan~routeCount=1 & plan~routes[1]~id='NUMERICAL-RESIDUAL','standard planner selects numerical residual obligation'
p=x~prove(claim,.nil,'STANDARD')
call check p~outcome='PROVED' & p~status='NUMERICALLY_SATISFIED','standard policy preserves numerical residual semantics'
call check p~plan~policy~name='STANDARD' & p~attempts~items=1,'proof retains standard plan and attempt ledger'
call check p~attempts[1]~route~role='OBLIGATION','attempt records proof-obligation role'
call check p~primaryEvidence~steps[1]~operation='matrix.solve.residual','residual proof has its own path separate from solution computation'

cp=.Maths~planProof(x,claim,.nil,'CERTIFIED')
call check cp~routeCount=1 & cp~routes[1]~id='EXACT-REPRESENTED-RESIDUAL','certified policy selects exact represented-value residual route'
c=x~prove(claim,.nil,'CERTIFIED')
call check c~outcome='PROVED' & c~status='EXACT_BOUND_CERTIFIED','certified policy proves residual bound by exact rational replay'
call check c~primaryEvidence~steps[1]~guarantee='EXACT_BOUND_ON_REPRESENTED_VALUES','exact residual certificate states its precise guarantee'
call check c~checks['residualExact']='integer[0]','exact residual certificate exposes exact zero'

sp=.Maths~planProof(x,claim,.nil,'STRONG')
call check sp~routeCount=3,'strong solve plan contains exact, numerical and support routes'
call check sp~routes[3]~role='SUPPORT' & sp~routes[3]~claim~kind='INDEPENDENT_REPRODUCTION','strong planner distinguishes supporting reproduction from equation claim'
s=x~prove(claim,.nil,'STRONG')
call check s~outcome='PROVED' & s~status='EXACT_BOUND_CERTIFIED','strong policy selects strongest successful obligation'
call check s~checks['supportProved']=1 & s~checks['corroborated']=1,'strong policy records successful independent corroboration'
call check s~verificationEvidence~primaryProvider='REFERENCE','strong proof surfaces the independent reference path as verification evidence'

acc=x~prove(.MathClaim~accurateDigits(40),.nil,'CERTIFIED')
call check acc~outcome='INDETERMINATE' & acc~plan~routeCount=0,'planner refuses generic digits-of-accuracy proof without forward-error certificate'

r=.Maths~rational(2,3)
rp=r~prove(.MathClaim~equals('0.6666666666666666666666666666666666666666666666666667'),.nil,'STRONG')
call check rp~outcome='DISPROVED','strong policy does not replace exact rational equality with decimal closeness'
rexact=r~prove(.MathClaim~isExact,.nil,'STRONG')
call check rexact~outcome='PROVED' & rexact~status='EXACT','single exact route remains sufficient when no alternate route exists'

if failures=0 then do; say 'PASS oorexx_maths proof planner 18 assertions'; exit 0; end
say 'FAIL oorexx_maths proof planner failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathsBootstrap.cls'
