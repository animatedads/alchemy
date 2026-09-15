numeric digits 50
failures=0
ctx=.MathContext~rational

third=.Maths~fraction(1,3,ctx)
e=third~decimalExpansion
call check e~isA(.MathDecimalExpansion),'fraction exposes MathDecimalExpansion object'
call check e~string='0.(3)','1/3 exact recurring expansion is 0.(3)'
call check e~isRecurring & \e~isTerminating & e~periodLength=1,'1/3 expansion records recurring period'
call check e~toRational=third,'decimal expansion round-trips to exact rational source'
call check e~evidence~steps[1]~guarantee='EXACT','decimal expansion path declares exact guarantee'

call check .Maths~fraction(2,3,ctx)~format('EXPANSION')='0.(6)','2/3 exact expansion avoids rounded finite decimal'
call check .Maths~fraction(1,6,ctx)~format('EXPANSION')='0.1(6)','1/6 expansion separates non-repeating and recurring digits'
call check .Maths~fraction(1,8,ctx)~format('EXPANSION')='0.125','terminating rational expansion is finite'
call check .Maths~fraction(22,7,ctx)~format('EXPANSION')='3.(142857)','22/7 recurring cycle is represented exactly'
call check .Maths~fraction(-1,6,ctx)~format('EXPANSION')='-0.1(6)','negative repeating decimal retains sign exactly'

call check .Maths~exact('0.(3)',ctx)=third,'exact parser converts recurring 0.(3) to 1/3'
call check .Maths~exact('0.(6)',ctx)=.Maths~fraction(2,3,ctx),'exact parser converts recurring 0.(6) to 2/3'
call check .Maths~exact('0.1(6)',ctx)=.Maths~fraction(1,6,ctx),'exact parser converts mixed recurring decimal 0.1(6) to 1/6'
call check .Maths~exact('3.(142857)',ctx)=.Maths~fraction(22,7,ctx),'exact parser converts 3.(142857) to 22/7'
call check .Maths~exact('0.(9)',ctx)~isA(.MathInteger) & .Maths~exact('0.(9)',ctx)=1,'0.(9) canonicalizes exactly to integer 1'
call check .Maths~exact('-0.1(6)',ctx)=.Maths~fraction(-1,6,ctx),'negative repeating literal parses exactly'
call check third='0.(3)','rational comparison coerces exact recurring-decimal literal without floating conversion'
call check (third+'0.(6)')~isA(.MathInteger) & third+'0.(6)'=1,'recurring-decimal literal participates in exact overloaded arithmetic'
factoryExpansion=.Maths~decimalExpansion('0.(6)',100,ctx)
call check factoryExpansion~string='0.(6)' & factoryExpansion~toRational=.Maths~fraction(2,3,ctx),'Maths decimalExpansion factory round-trips recurring exact input'
exactProof=e~prove
call check exactProof~outcome='PROVED' & exactProof~status='EXACT','decimal expansion exactness proof succeeds'
call check exactProof~checks['exactRoundTrip']='1' & exactProof~verificationEvidence~steps[1]~algorithm='exact-geometric-series-decimal-conversion','decimal expansion proof replays through distinct exact inverse conversion'

x=.Maths~fraction(2,3,ctx)
display=x~format('DECIMAL',24)
exactDisplay=x~format('EXPANSION')
call check display='0.666666666666666666666667','rounded decimal presentation remains available explicitly'
call check exactDisplay='0.(6)','exact expansion presentation remains distinct from rounded decimal'
call check x*3/2=1,'requesting either presentation cannot contaminate subsequent exact arithmetic'
call check expectPeriodLimit(),'period resource limit fails rather than returning a truncated expansion as exact'

if failures=0 then do; say 'PASS oorexx_maths decimal expansion 25 assertions'; exit 0; end
say 'FAIL oorexx_maths decimal expansion failures='failures; exit 1
expectPeriodLimit: procedure
  signal on syntax name caught
  ignored=.Maths~fraction(1,7)~decimalExpansion(3)
  return .false
caught:
  return .true

check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label; return
::requires 'MathsBootstrap.cls'
