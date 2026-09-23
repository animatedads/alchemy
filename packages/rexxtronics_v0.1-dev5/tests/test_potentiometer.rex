/* Qualification: three-terminal potentiometer has an inspectable wiper voltage. */
numeric digits 50

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', 10))
p = c~add(.Potentiometer~new('P1', 10000, 0.25))

c~connect('VCC', .array~of(v~positive, p~pin('A')))
c~connect('WIPER', p~pin('W'))
c~connectGround(p~pin('B'))
c~connectGround(v~negative)

s = c~solveDC
if abs(s~voltage('WIPER') - 2.5) > 0.00001 then do
  say 'FAIL: WIPER expected 2.5 V, got' s~voltage('WIPER')
  exit 1
end

p~setPosition(0.75)
s = c~solveDC
if abs(s~voltage('WIPER') - 7.5) > 0.00001 then do
  say 'FAIL: WIPER expected 7.5 V, got' s~voltage('WIPER')
  exit 1
end

say 'REXX-TRONICS POTENTIOMETER: OK'
say 'wiper at 75 percent:' s~voltage('WIPER') 'V'
exit 0

::requires 'RexxTronicsDC.cls'
