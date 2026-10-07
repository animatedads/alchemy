numeric digits 50
failures=0
ctx=.MathContext~decimal(50)
x=.Maths~variable('x',ctx)
expr=(x*2)-(x*2)
claim=.MathClaim~equals(0)
plan=.Maths~planProof(expr,claim,.nil,'STRONG')
call check plan~routeCount=2,'strong symbolic plan selects two implementation-distinct routes'
call check plan~routes[1]~id='SYMPY-SYMBOLIC' & plan~routes[2]~id='LOCAL-STRUCTURAL','strong symbolic plan records CAS and local routes explicitly'
p=expr~prove(claim,.nil,'STRONG')
call check p~outcome='PROVED','strong symbolic identity is corroborated'
call check p~attempts~items=2 & p~checks['corroborated']=1,'strong symbolic proof retains both successful attempts'
call check p~primaryEvidence~primaryProvider='PURE','planner selects exact local rewrite as strongest evidence'
call check p~verificationEvidence~primaryProvider='SYMPY','planner retains SymPy as materially different verification evidence'

expr2=(x+1)*(x-1)
claim2=.MathClaim~equals((x**2)-1)
p2=expr2~prove(claim2,.nil,'STRONG')
call check p2~outcome='INDETERMINATE' & p2~status='CORROBORATION_REQUIRED','strong policy distinguishes one valid symbolic proof from independently corroborated proof'
call check p2~attempts[1]~outcome='PROVED' & p2~attempts[2]~outcome='INDETERMINATE','attempt ledger preserves proved and inconclusive routes separately'

cert=expr2~prove(claim2,.nil,'CERTIFIED')
call check cert~outcome='PROVED' & cert~status='SYMBOLICALLY_PROVED','certified policy accepts a scoped exact symbolic certificate without pretending local corroboration exists'

if failures=0 then do; say 'PASS oorexx_maths proof planner providers 9 assertions'; exit 0; end
say 'FAIL oorexx_maths proof planner providers failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathProofProviders.cls'
