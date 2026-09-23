parse source . . here
base=filespec('L',here)
map=.SnmpImplementationMapLoader~new~loadFile(base||'../maps/ietf_minimal.json')
initial=.directory~new
initial['1.3.6.1.2.1.2.2.1.1.2']='2'
initial['1.3.6.1.2.1.2.2.1.2.2']='lan0'
initial['1.3.6.1.2.1.2.2.1.8.2']='1'
initial['1.3.6.1.2.1.2.2.1.1.17']='17'
initial['1.3.6.1.2.1.2.2.1.2.17']='wan0'
initial['1.3.6.1.2.1.2.2.1.8.17']='2'
transport=.SnmpMemoryTransport~new(initial)
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('router-a',session,map)
interfaces=router~interfaces
rows=interfaces~rows
if rows~items<>2 then do; say 'FAIL row discovery count' rows~items; exit 1; end
if rows[1]~index~string<>'17' & rows[1]~index~string<>'2' then do; say 'FAIL row index'; exit 1; end
seen=.directory~new
do row over interfaces
  seen[row~description]=row~operStatus
end
call assertEqual 'up',seen['lan0'],'enumerated lan row'
call assertEqual 'down',seen['wan0'],'enumerated wan row'
say 'PASS table walk -> managed row enumeration'
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
  return

::requires '../src/Snmp.cls'
