/* Qualification: unconnected pins are reported and path tracing crosses components/nets. */

c = .Circuit~new
r1 = c~add(.Resistor~new('R1', 1000))
r2 = c~add(.Resistor~new('R2', 2200))

/* Leave R2.B open first: topology validation must catch it. */
c~connect('START', r1~pin('A'))
c~connect('MID', .array~of(r1~pin('B'), r2~pin('A')))

report = c~validateTopology
if report~ok then do
  say 'FAIL: open pin was not reported'
  exit 1
end
if report~errorCount <> 1 then do
  say 'FAIL: expected one topology error, got' report~errorCount
  exit 1
end

c~connect('END', r2~pin('B'))
report = c~validateTopology
if \report~ok then do
  say 'FAIL: completed topology should validate'
  exit 1
end

path = c~tracePath(r1~pin('A'), r2~pin('B'))
if path~items <> 4 then do
  say 'FAIL: expected four-pin resistor-chain path, got' path~items
  exit 1
end
if path[1] <> 'R1.A' | path[2] <> 'R1.B' | path[3] <> 'R2.A' | path[4] <> 'R2.B' then do
  say 'FAIL: unexpected path sequence'
  do p over path
    say p
  end
  exit 1
end

say 'REXX-TRONICS TOPOLOGY/PATH: OK'
say 'path pin hops:' path~items
line = ''
do p over path
  if line = '' then line = p
  else line = line || ' -> ' || p
end
say line
exit 0

::requires 'RexxTronicsDC.cls'
