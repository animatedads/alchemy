/* Solver stamping must not collapse shared Units high precision back to the
 * ooRexx default method precision. */
numeric digits 50
failures=0
value='3.1697464752475247524752475247524752475'
c=.Circuit~new
v=c~add(.DCVoltageSource~new('V1',.Units~q(value,.Units~volt)))
r=c~add(.Resistor~new('R1','1 kohm'))
c~connect('OUT',.array~of(v~positive,r~pin('A')))
c~connectGround(v~negative)
c~connectGround(r~pin('B'))
s=c~solveDC
call near s~voltage('OUT'),value,'high-precision stamped voltage','1e-40'
call near r~current~in(.Units~ampere),value/1000,'high-precision resistor current','1e-40'
if failures=0 then do
  say 'REXX-TRONICS SOLVER PRECISION BOUNDARY: OK'
  say 'OUT:' s~voltage('OUT') 'V'
  say 'I:' r~current~in(.Units~ampere) 'A'
  exit 0
end
say 'FAIL solver precision failures='failures
exit 1
near: procedure expose failures
  use arg actual,expected,label,tolerance='1e-30'
  if abs(actual-expected)>tolerance then do
    say 'FAIL:' label 'actual='actual 'expected='expected
    failures+=1
  end
return
::requires 'RexxTronicsDC.cls'
