/* Qualification: variable resistor updates deterministic DC behaviour. */
numeric digits 50

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', 10))
rv = c~add(.VariableResistor~new('RV1', 1000, 9000, 0))
load = c~add(.Resistor~new('RL', 1000))

c~connect('VCC', .array~of(v~positive, rv~pin('A')))
c~connect('OUT', .array~of(rv~pin('B'), load~pin('A')))
c~connectGround(load~pin('B'))
c~connectGround(v~negative)

s1 = c~solveDC
if abs(rv~resistanceOhms - 1000) > 0.000001 then do
  say 'FAIL: RV1 expected 1k at position 0'
  exit 1
end
if abs(s1~voltage('OUT') - 5) > 0.000001 then do
  say 'FAIL: OUT expected 5 V at 1k, got' s1~voltage('OUT')
  exit 1
end

rv~setPosition(1)
s2 = c~solveDC
if abs(rv~resistanceOhms - 9000) > 0.000001 then do
  say 'FAIL: RV1 expected 9k at position 1'
  exit 1
end
if abs(s2~voltage('OUT') - 1) > 0.000001 then do
  say 'FAIL: OUT expected 1 V at 9k, got' s2~voltage('OUT')
  exit 1
end

say 'REXX-TRONICS VARIABLE RESISTOR: OK'
say 'position 0 OUT:' s1~voltage('OUT') 'V'
say 'position 1 OUT:' s2~voltage('OUT') 'V'
exit 0

::requires 'RexxTronicsDC.cls'
