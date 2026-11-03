numeric digits 50
failures=0
ctx=.MathContext~decimal(50)
call check ctx~requestedDigits=50,'default precision is 50 digits'
call check .Maths~provider('PURE') \== .nil,'pure provider registered'
call check .Maths~provider('REFERENCE') \== .nil,'reference provider registered'

z1=.Maths~complex(2,3,ctx); z2=.Maths~complex(4,-1,ctx); z3=z1+z2
call check z3~real=6 & z3~imaginary=2,'complex overloaded +'
z4=z1*z2
call check z4~real=11 & z4~imaginary=10,'complex overloaded *'

v1=.Maths~vector(.array~of(1,2,3),ctx); v2=.Maths~vector(.array~of(4,5,6),ctx)
call check v1*v2=32,'vector * vector is dot product'
v3=v1+v2
call check v3[1]=5 & v3[3]=9,'vector overloaded +'

A=.Maths~matrix(.array~of(.array~of(1,2),.array~of(3,4)),ctx)
B=.Maths~matrix(.array~of(.array~of(5,6),.array~of(7,8)),ctx)
C=A+B
call check C[1,1]=6 & C[2,2]=12,'matrix overloaded +'
D=A*B
call check D[1,1]=19 & D[1,2]=22 & D[2,1]=43 & D[2,2]=50,'matrix overloaded *'
call check D~evidence~primaryProvider='PURE','matrix multiplication evidence provider'
T=A~transpose
call check T[1,2]=3 & T[2,1]=2,'matrix transpose'
I=A~inverse * A
call check (I[1,1]-1)~abs < 1E-45 & I[1,2]~abs < 1E-45 & I[2,1]~abs < 1E-45 & (I[2,2]-1)~abs < 1E-45,'matrix inverse/identity relation'

S=.Maths~matrix(.array~of(.array~of(3,2),.array~of(1,2)),ctx)
b=.Maths~vector(.array~of(5,5),ctx)
x=S~solve(b)
call check (x[1]-0)~abs < 1E-45 & (x[2]-2.5)~abs < 1E-45,'pure solve'
call check x~evidence~checks['residualInf'] < 1E-45,'solve residual recorded'
p=x~prove
call check p~status='VERIFIED_NUMERICALLY','solve independent proof status'
call check p~verificationEvidence~primaryProvider='REFERENCE','proof uses reference provider'
call check p~checks['maxAbsDifference'] < 1E-45,'independent solve agrees'
again=x~doAgainDifferently
call check again~evidence~steps[1]~algorithm='gauss-jordan-partial-pivot','doAgainDifferently uses distinct algorithm'

if failures=0 then do; say 'PASS oorexx_maths core 18 assertions'; exit 0; end
say 'FAIL oorexx_maths core failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathsBootstrap.cls'
