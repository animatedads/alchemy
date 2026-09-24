/* Qualification: linear resistive DC solve by modified nodal analysis. */
numeric digits 50

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', 9))
r1 = c~add(.Resistor~new('R1', 1000))
r2 = c~add(.Resistor~new('R2', 2000))

c~connect('VCC', .array~of(v~positive, r1~pin('A')))
c~connect('MID', .array~of(r1~pin('B'), r2~pin('A')))
c~connectGround(r2~pin('B'))
c~connectGround(v~negative)

solution = c~solveDC

if \solution~converged then do
  say 'FAIL: DC solver did not converge'
  exit 1
end
if abs(solution~voltage('VCC') - 9) > 0.0000001 then do
  say 'FAIL: VCC expected 9 V, got' solution~voltage('VCC')
  exit 1
end
if abs(solution~voltage('MID') - 6) > 0.0000001 then do
  say 'FAIL: MID expected 6 V, got' solution~voltage('MID')
  exit 1
end
if abs(solution~current(r1) - 0.003) > 0.000000001 then do
  say 'FAIL: R1 expected 3 mA, got' solution~current(r1)
  exit 1
end
if abs(solution~current(r2) - 0.003) > 0.000000001 then do
  say 'FAIL: R2 expected 3 mA, got' solution~current(r2)
  exit 1
end
if abs(solution~power(r1) - 0.009) > 0.000000001 then do
  say 'FAIL: R1 expected 9 mW, got' solution~power(r1)
  exit 1
end
if abs(solution~power(r2) - 0.018) > 0.000000001 then do
  say 'FAIL: R2 expected 18 mW, got' solution~power(r2)
  exit 1
end

say 'REXX-TRONICS DC VOLTAGE DIVIDER: OK'
say 'VCC:' solution~voltage('VCC') 'V'
say 'MID:' solution~voltage('MID') 'V'
say 'current:' solution~current(r1) 'A'
say 'R1 power:' solution~power(r1) 'W'
say 'R2 power:' solution~power(r2) 'W'
exit 0

::requires 'RexxTronicsDC.cls'
