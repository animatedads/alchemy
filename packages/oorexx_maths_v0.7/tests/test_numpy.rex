numeric digits 50
failures=0
ctx=.MathContext~binary64('NUMPY')
A=.Maths~matrix(.array~of(.array~of(1,2),.array~of(3,4)),ctx)
B=.Maths~matrix(.array~of(.array~of(5,6),.array~of(7,8)),ctx)
C=A*B
call check C[1,1]=19 & C[2,2]=50,'NumPy matrix operator product'
call check C~evidence~primaryProvider='NUMPY','NumPy evidence provider'
call check C~evidence~steps[1]~guarantee='APPROXIMATE_IEEE754','NumPy path explicitly declares approximate IEEE-754 guarantee'
call check C~evidence~steps[1]~independenceTags~pos('NUMPY')>0,'NumPy path records implementation lineage tags'
call check C~evidence~steps[1]~details~pos('LAPACK=')>0,'NumPy evidence identifies BLAS/LAPACK stack'
call check C~backendProvider='NUMPY','NumPy result retains resident backend object'
D=C+A
call check D[1,1]=20 & D[2,2]=54,'resident NumPy result reused by next operator'
S=.Maths~matrix(.array~of(.array~of(3,2),.array~of(1,2)),ctx)
b=.Maths~vector(.array~of(5,5),ctx)
x=S~solve(b)
call check (x[1]-0)~abs < 1E-12 & (x[2]-2.5)~abs < 1E-12,'NumPy solve'
p=x~prove
call check p~status='VERIFIED_NUMERICALLY','NumPy solve independently verified'
call check p~verificationEvidence~primaryProvider='REFERENCE','NumPy proof switches provider'
call check x~evidence~warnings~items>0,'binary64 evidence records precision warning'

/* Deliberately ill-conditioned Hilbert system: binary64 must not be rubber-stamped. */
n=10; rows=.array~new; hb=.array~new
Do i=1 to n
  row=.array~new; s=0
  do j=1 to n
    v=1/(i+j-1); row~append(v); s=s+v
  end
  rows~append(row); hb~append(s)
end
H=.Maths~matrix(rows,ctx); hv=.Maths~vector(hb,ctx)
hx=H~solve(hv); hp=hx~prove
call check hp~status='DISAGREEMENT','ill-conditioned binary64 solve is not rubber-stamped'
call check hp~checks['maxAbsDifference'] > 1E-6,'disagreement magnitude is exposed'
call check hp~checks['verificationResidualInf'] < hp~checks['residualInf'],'higher-precision verification residual is better'
if failures=0 then do; say 'PASS oorexx_maths NumPy 14 assertions'; exit 0; end
say 'FAIL oorexx_maths NumPy failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathNumpyProvider.cls'
