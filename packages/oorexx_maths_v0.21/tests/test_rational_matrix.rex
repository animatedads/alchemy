numeric digits 50
failures=0
ctx=.MathContext~rational
call check ctx~numberDomain='RATIONAL','rational context declares exact domain'
A=.Maths~matrix(.array~of(.array~of(1,2),.array~of(3,4)),ctx)
B=.Maths~matrix(.array~of(.array~of('1/2','1/3'),.array~of('1/4','1/5')),ctx)
call check A[1,1]~isA(.MathRational) & B[1,1]~string='1/2','ordinary MathMatrix retains rational objects in RATIONAL context'
C=A+B
call check C[1,1]~string='3/2' & C[2,2]~string='21/5','matrix overloaded + stays exact rational'
D=A*B
call check D[1,1]~string='1' & D[1,2]~string='11/15','matrix overloaded * stays exact rational'
v1=.Maths~vector(.array~of('1/3','2/5'),ctx)
v2=.Maths~vector(.array~of('3/7','5/2'),ctx)
dot=v1*v2
call check dot~isA(.MathRational) & dot~string='8/7','vector dot product returns exact rational'
call check dot~evidence~operation='vector.dot','exact dot product records semantic operation path'

b=.Maths~vector(.array~of(5,11),ctx)
x=A~solve(b)
call check x[1]~string='1' & x[2]~string='2','ordinary matrix solve is exact in rational context'
call check x~evidence~steps[1]~numberDomain='RATIONAL','exact solve path records rational domain'
call check x~evidence~steps[1]~guarantee='EXACT','exact solve path declares exact guarantee'
call check x~evidence~steps[1]~independenceTags~pos('RATIONAL')>0,'exact solve path records independence lineage'
call check x~evidence~checks['residualInf']~isA(.MathRational) & x~evidence~checks['residualInf']~numerator=0,'exact solve records exact zero residual'
pr=x~prove
call check pr~outcome='PROVED' & pr~status='EXACTLY_REPRODUCED','do-it-again-differently exact solve agrees through independent algorithm'
call check pr~verificationEvidence~steps[1]~algorithm='gauss-jordan-partial-pivot','independent exact solve uses distinct Gauss-Jordan path'
peq=x~prove(.MathClaim~satisfiesEquation('0'))
call check peq~outcome='PROVED' & peq~status='EXACT','exact zero equation residual promotes proof strength to EXACT'

I=A~inverse*A
call check I[1,1]~string='1' & I[1,2]~string='0' & I[2,1]~string='0' & I[2,2]~string='1','inverse relation is exact in rational context'

if failures=0 then do; say 'PASS oorexx_maths rational matrix 15 assertions'; exit 0; end
say 'FAIL oorexx_maths rational matrix failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label; return
::requires 'MathsBootstrap.cls'
