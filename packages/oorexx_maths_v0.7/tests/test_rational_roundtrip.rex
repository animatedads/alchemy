/* Regression derived from the supplied test.rex.
 * Native ooRexx decimal division materializes an approximation to i/(3*i).
 * The exact Maths path must retain the rational 1/3 and round-trip exactly. */
numeric digits 50
failures=0
ctx=.MathContext~rational
third=.Maths~fraction(1,3,ctx)

do i=1 to 25
  j=i*3
  f=.Maths~fraction(i,j,ctx)
  x=f*j
  call check f=third,'round-trip case' i 'retains exact canonical 1/3'
  call check x~isA(.MathInteger) & x=i,'round-trip case' i 'returns exact integer after multiplying by' j
end

if failures=0 then do; say 'PASS oorexx_maths rational round-trip 50 assertions'; exit 0; end
say 'FAIL oorexx_maths rational round-trip failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label; return
::requires 'MathsBootstrap.cls'
