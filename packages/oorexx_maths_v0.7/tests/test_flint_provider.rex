numeric digits 50
failures=0
p=.Maths~provider('FLINT-ARB')
if p == .nil then do
  say 'SKIP oorexx_maths FLINT-ARB: python-flint >= 0.9.0 not available on qualification host'
  exit 0
end
call check p~version<>'' ,'FLINT-ARB provider records version'
ctx=.MathContext~decimal(50)
x=.Maths~variable('x',ctx)
expr=(x*2)-(x*2)
bounds=.directory~new; bounds['x']=.array~of('0','1')
ball=expr~ball(bounds,ctx)
call check ball~provider='FLINT-ARB','ball result records FLINT-ARB provider'
call check ball~evidence~steps[1]~guarantee='RIGOROUS_BALL_ENCLOSURE','ball path declares rigorous enclosure guarantee'
call check ball~evidence~checks~hasIndex('certificateMid') & ball~evidence~checks~hasIndex('certificateRadius'),'ball evidence carries midpoint-radius certificate components'
bp=ball~prove(.MathClaim~enclosesExactEvaluation)
call check bp~outcome='PROVED' & bp~status='BALL_CERTIFIED','Arb enclosure proves scoped containment claim'
call check bp~claim~kind='ENCLOSES_EXACT_EVALUATION','ball proof retains exact claim scope'
call check bp~plan~routeCount=1 & bp~plan~routes[1]~id='BALL-CERTIFICATE','Arb proof is routed through explicit planner certificate obligation'
call check bp~attempts~items=1 & bp~attempts[1]~outcome='PROVED','Arb proof retains certificate attempt ledger'
if failures=0 then do; say 'PASS oorexx_maths FLINT-ARB 8 assertions'; exit 0; end
say 'FAIL oorexx_maths FLINT-ARB failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label; return
::requires 'MathProofProviders.cls'
