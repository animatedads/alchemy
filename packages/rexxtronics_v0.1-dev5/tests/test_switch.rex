/* Qualification: switch affects both electrical solve and connectivity trace. */
numeric digits 50

c = .Circuit~new
v = c~add(.DCVoltageSource~new('V1', 5))
sw = c~add(.Switch~new('S1', .false))
r = c~add(.Resistor~new('R1', 1000))

c~connect('VCC', .array~of(v~positive, sw~pin('A')))
c~connect('LOAD', .array~of(sw~pin('B'), r~pin('A')))
c~connectGround(r~pin('B'))
c~connectGround(v~negative)

openResult = c~solveDC
if openResult~voltage('LOAD') > 0.000001 then do
  say 'FAIL: open switch leaked too much voltage:' openResult~voltage('LOAD')
  exit 1
end
if sw~electricalPathPeers(sw~pin('A'))~items <> 0 then do
  say 'FAIL: open switch exposes a conductive branch'
  exit 1
end

sw~close
closedResult = c~solveDC
if abs(closedResult~voltage('LOAD') - 5) > 0.00001 then do
  say 'FAIL: closed switch expected 5 V, got' closedResult~voltage('LOAD')
  exit 1
end
if sw~electricalPathPeers(sw~pin('A'))~items <> 1 then do
  say 'FAIL: closed switch branch missing'
  exit 1
end

say 'REXX-TRONICS SWITCH: OK'
say 'open LOAD:' openResult~voltage('LOAD') 'V'
say 'closed LOAD:' closedResult~voltage('LOAD') 'V'
exit 0

::requires 'RexxTronicsDC.cls'
