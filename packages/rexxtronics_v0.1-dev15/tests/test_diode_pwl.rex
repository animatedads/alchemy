/* Qualification: deterministic piecewise-linear silicon diode and nonlinear DC iteration. */
numeric digits 50

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', '5 V'))
r = c~add(.Resistor~new('R1', '1 kOhm'))
d = c~add(.Diode~new('D1', '0.7 V', '1 Ohm'))
c~connectGround(v~negative)
c~connect('VCC', .array~of(v~positive, r~pin('A')))
c~connect('D', .array~of(r~pin('B'), d~anode))
c~connectGround(d~cathode)
s = c~solveDC
if d~state <> 'FORWARD' then do; say 'FAIL: forward diode state' d~state; exit 1; end
if s~iterations < 2 then do; say 'FAIL: nonlinear solve did not iterate'; exit 1; end
if abs(s~voltage('D') - '0.7042957042957042957042957042957') > 0.000001 then do
  say 'FAIL: forward diode voltage' s~voltage('D'); exit 1
end
if abs(s~current(d) - '0.0042957042957042957042957042957') > 0.00000001 then do
  say 'FAIL: forward diode current' s~current(d); exit 1
end

r2c = .Circuit~new
v2 = r2c~add(.DCVoltageSource~new('V2', '5 V'))
r2 = r2c~add(.Resistor~new('R2', '1 kOhm'))
d2 = r2c~add(.Diode~new('D2'))
r2c~connectGround(v2~negative)
r2c~connect('VCC', .array~of(v2~positive, r2~pin('A')))
r2c~connect('K', .array~of(r2~pin('B'), d2~cathode))
r2c~connectGround(d2~anode)
s2 = r2c~solveDC
if d2~state <> 'OFF' then do; say 'FAIL: reverse diode state' d2~state; exit 1; end
if abs(s2~current(d2)) > 0.000000001 then do; say 'FAIL: reverse leakage too large' s2~current(d2); exit 1; end

say 'REXX-TRONICS DIODE NONLINEAR DC: OK'
say 'forward voltage:' s~voltage('D') 'V'
say 'forward current mA:' s~current(d) * 1000
say 'iterations:' s~iterations
exit 0
::requires 'RexxTronicsDC.cls'
