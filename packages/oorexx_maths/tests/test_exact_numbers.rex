numeric digits 50
failures=0
ctx=.MathContext~rational

one=.Maths~integer(1,ctx)
call check one~isA(.MathInteger),'integer factory returns MathInteger'
call check one~isA(.MathRational),'MathInteger remains rational-compatible'
call check one~string='1' & one~denominator=1,'integer canonical representation is denominator one'

third=.Maths~fraction(1,3,ctx)
call check third~isA(.MathFraction) & third~isA(.MathRational) & \third~isA(.MathInteger),'proper fraction canonicalizes to MathFraction within rational hierarchy'
call check .Maths~rational(2,3,ctx)~isA(.MathFraction),'rational factory selects proper MathFraction subtype'
call check .Maths~fraction(3,3,ctx)~isA(.MathInteger),'fraction canonicalizes n/n to MathInteger'
call check .Maths~fraction(0,99999999999999999999999999999999999999999999999999,ctx)~isA(.MathInteger),'zero fraction canonicalizes to MathInteger zero'

sum=third+third+third
call check sum~isA(.MathInteger) & sum=1,'1/3 + 1/3 + 1/3 canonicalizes exactly to integer 1'
call check sum~evidence~checks['unreduced']='3/3','exact path retains unreduced 3/3 before canonicalization'
call check sum~evidence~checks['canonical']='1','exact path records canonical integer result'

r=.Maths~fraction(2,3,ctx)*3/2
call check r~isA(.MathInteger) & r=1,'(2/3) * 3 / 2 remains exact integer 1 without rounded decimal materialization'
call check r~evidence~checks['unreduced']='2/2','final division records exact unreduced fraction before reduction'

six=.Maths~integer(6,ctx)
call check (six/3)~isA(.MathInteger) & six/3=2,'exact integer division stays integer when divisible'
call check (six/4)~isA(.MathRational) & \(six/4)~isA(.MathInteger) & (six/4)~string='3/2','exact integer division promotes to rational when not divisible'
call check (.Maths~fraction(2,6,ctx)=.Maths~fraction(1,3,ctx)),'exact rational equality is value equality'
call check (.Maths~fraction(1,3,ctx)<.Maths~fraction(1,2,ctx)),'exact rational ordering uses rational arithmetic'

call check .Maths~exact('3/3',ctx)~isA(.MathInteger),'exact fraction literal canonicalizes to integer'
call check .Maths~exact('0.1',ctx)~string='1/10','exact decimal literal becomes rational without binary float'
call check .Maths~exact('12',ctx)~isA(.MathInteger),'exact integer literal becomes MathInteger'
call check .Maths~exact('1.2e-3',ctx)~string='3/2500','exact scientific decimal literal becomes rational'

x=.Maths~fraction(2,3,ctx)
display=x~format('DECIMAL',24)
call check x~string='2/3' & x~isExact,'decimal formatting does not mutate exact representation'
call check (x*3/2)=1,'arithmetic after decimal formatting still uses exact 2/3 representation'
call check .Maths~fraction(7,3,ctx)~format('MIXED')='2 1/3','mixed-number formatting is presentation only'

huge=.Maths~fraction('123456789012345678901234567890123456789012345678901234567890',3,ctx)
call check huge~isA(.MathInteger) & huge~string='41152263004115226300411522630041152263004115226300411522630','large exact fraction canonicalizes to integer beyond default numeric digits'

if failures=0 then do; say 'PASS oorexx_maths exact numbers 24 assertions'; exit 0; end
say 'FAIL oorexx_maths exact numbers failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label; return
::requires 'MathsBootstrap.cls'
