numeric digits 50
failures=0
ctx=.MathContext~binary64('NUMPY')

/* Ill-conditioned Hilbert solve: a loose residual claim can be true while
 * independent reproduction of the solution fails. STRONG must preserve that distinction.
 */
n=10; rows=.array~new; hb=.array~new
do i=1 to n
  row=.array~new; sum=0
  do j=1 to n
    v=1/(i+j-1); row~append(v); sum=sum+v
  end
  rows~append(row); hb~append(sum)
end
H=.Maths~matrix(rows,ctx); b=.Maths~vector(hb,ctx); x=H~solve(b)
claim=.MathClaim~satisfiesEquation('1E-8')
proof=x~prove(claim,.nil,'STRONG')
call check proof~outcome='INDETERMINATE' & proof~status='CORROBORATION_REQUIRED','strong policy does not confuse small residual with reproduced solution'
call check proof~checks['obligationProved']=2,'exact and numerical residual obligations can both succeed'
call check proof~checks['supportFailed']=1 & proof~checks['supportProved']=0,'independent solution reproduction failure is retained as supporting evidence'
call check proof~attempts[3]~route~role='SUPPORT' & proof~attempts[3]~strength='DISAGREEMENT','support attempt records materially different solver disagreement'
call check proof~attempts[1]~proof~checks['residualExact']<>'' ,'exact represented-value residual survives large rational intermediates'
call check proof~attempts[1]~proof~primaryEvidence~steps[1]~guarantee='EXACT_BOUND_ON_REPRESENTED_VALUES','binary64 exact replay states represented-value scope rather than original-source scope'

/* CERTIFIED asks only whether the represented values satisfy the residual bound. */
cert=x~prove(claim,.nil,'CERTIFIED')
call check cert~outcome='PROVED' & cert~status='EXACT_BOUND_CERTIFIED','certified residual claim can be proved even when forward solution reproduction disagrees'
call check cert~notes[cert~notes~items]~pos('Scope warning')>0,'binary64 certificate carries explicit pre-conversion scope warning'

if failures=0 then do; say 'PASS oorexx_maths proof planner NumPy 8 assertions'; exit 0; end
say 'FAIL oorexx_maths proof planner NumPy failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathNumpyProvider.cls'
