numeric digits 50
assertions=0
ctx=.MathContext~binary64('RXMATH')
call check .Maths~provider('RXMATH') \== .nil, 'RxMath native provider registered'; assertions+=1
r=.Maths~scalarResult('SIN','0.5',ctx)
call check r~evidence~primaryProvider='RXMATH', 'native scalar evidence provider'; assertions+=1
call near r~value,'0.479425538604203', '2E-15', 'native sin value'; assertions+=1
call check r~evidence~steps[1]~guarantee='APPROXIMATE_16_DIGIT_NATIVE', 'native scalar declares 16-digit approximate guarantee'; assertions+=1
p=r~prove(.MathClaim~independentlyReproduced('2E-15'))
call check p~outcome='PROVED', 'native sin independently reproduced'; assertions+=1
call check p~verificationEvidence~primaryProvider='REFERENCE', 'native sin proof uses reference provider'; assertions+=1
call check p~checks['differentProvider'], 'native scalar proof records different provider'; assertions+=1
call check p~checks['differentAlgorithm'], 'native scalar proof records different algorithm'; assertions+=1

r=.Maths~scalarResult('COS','0.5',ctx); call near r~value,'0.8775825618903728','2E-15','native cos'; assertions+=1
r=.Maths~scalarResult('TAN','0.5',ctx); call near r~value,'0.5463024898437905','2E-15','native tan'; assertions+=1
r=.Maths~scalarResult('SQRT','2',ctx); call near r~value,'1.414213562373095','2E-15','native sqrt'; assertions+=1
r=.Maths~scalarResult('EXP','1',ctx); call near r~value,'2.718281828459045','3E-15','native exp'; assertions+=1
r=.Maths~scalarResult('LN','2',ctx); call near r~value,'0.6931471805599453','2E-15','native ln'; assertions+=1
r=.Maths~scalarResult('LOG10','1000',ctx); call near r~value,'3','1E-15','native log10'; assertions+=1
r=.Maths~scalarResult('ATAN','1',ctx); call near r~value,'0.7853981633974483','2E-15','native atan'; assertions+=1
r=.Maths~scalarResult('ATAN2',.array~of(1,-1),ctx); call near r~value,'2.356194490192345','3E-15','native atan2 quadrant II'; assertions+=1
r=.Maths~scalarResult('ATAN2',.array~of(-1,-1),ctx); call near r~value,'-2.356194490192345','3E-15','native atan2 quadrant III'; assertions+=1

/* AUTO chooses native scalar provider when it is registered. */
auto=.MathContext~binary64('AUTO')
r=.Maths~scalarResult('SIN','0.25',auto)
call check r~evidence~primaryProvider='RXMATH', 'AUTO binary64 scalar selects RxMath'; assertions+=1

/* Fail closed: no hidden decimal50 -> native16 narrowing. */
caught=.false
signal on syntax name expectedNarrowing
junk=.Maths~scalarResult('SIN','0.5',.MathContext~decimal(50,'RXMATH'))
signal off syntax
call check .false, 'RXMATH must reject DECIMAL context'; exit 1
expectedNarrowing:
  say 'EXPECTED CONDITION rc=' rc 'sigl=' sigl 'condition=' condition("C") 'description=' condition("D")
  signal off syntax
  caught=.true
  call check caught, 'RXMATH rejects hidden high-precision narrowing'; assertions+=1

say 'PASS oorexx_maths native RxMath' assertions 'assertions'
exit 0

check: procedure
  parse arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return
near: procedure
  parse arg actual,expected,tol,label
  numeric digits 50
  if (actual-expected)~abs>tol then do; say 'FAIL' label 'actual='actual 'expected='expected 'tol='tol; exit 1; end
  say 'PASS' label
  return

::requires 'MathRxMathProvider.cls'
