/* Qualification: reverse-breakdown piecewise-linear zener model. */
numeric digits 50
c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '9 V'))
r = c~add(.Resistor~new('R1', '1 kOhm'))
z = c~add(.ZenerDiode~new('ZD1', '5.1 V'))
c~connectGround(v~negative)
c~connect('VCC', .array~of(v~positive, r~pin('A')))
c~connect('Z', .array~of(r~pin('B'), z~cathode))
c~connectGround(z~anode)
s = c~solveDC
if z~state <> 'REVERSE' then do; say 'FAIL: zener not in breakdown' z~state; exit 1; end
if s~voltage('Z') < 5.1 | s~voltage('Z') > 5.2 then do; say 'FAIL: zener voltage' s~voltage('Z'); exit 1; end
if s~current(z) >= 0 then do; say 'FAIL: zener A->K current should be negative' s~current(z); exit 1; end
say 'REXX-TRONICS ZENER BREAKDOWN: OK'
say 'zener cathode voltage:' s~voltage('Z') 'V'
say 'zener current mA (A->K):' s~current(z) * 1000
exit 0
::requires 'RexxTronicsDC.cls'
