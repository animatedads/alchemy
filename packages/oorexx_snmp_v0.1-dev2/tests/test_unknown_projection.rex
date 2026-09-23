parse source . . here
base=filespec('L',here)
loader=.SnmpImplementationMapLoader~new
map=loader~loadFile(base||'../maps/ietf_minimal.json')
initial=.directory~new
initial['1.3.6.1.2.1.1.5.0']='router-a'
initial['1.3.6.1.2.1.1.4.0']='old-noc'
transport=.SnmpMemoryTransport~new(initial)
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('router-a',session,map)

call assertEqual 'router-a',router~sysName,'dynamic scalar getter through UNKNOWN'
router~sysContact='new-noc'
call assertEqual 'new-noc',router~sysContact,'dynamic scalar setter through UNKNOWN'
call assertEqual 1,transport~setCount,'one SET performed'

signal on syntax name readonlyCaught
router~sysDescr='nope'
say 'FAIL readonly setter did not reject'
exit 1
readonlyCaught:
  say 'PASS UNKNOWN GET/SET projection'
  exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
  return

::requires '../src/Snmp.cls'
