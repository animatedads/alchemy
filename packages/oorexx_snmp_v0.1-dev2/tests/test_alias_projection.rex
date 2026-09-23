parse source . . here
base=filespec('L',here)
map=.SnmpImplementationMapLoader~new~loadFile(base||'../maps/ietf_minimal.json')
initial=.directory~new
initial['1.3.6.1.2.1.1.1.0']='Example Router'
initial['1.3.6.1.2.1.1.3.0']='12345'
initial['1.3.6.1.2.1.1.5.0']='router-a'
initial['1.3.6.1.2.1.2.2.1.1.17']='17'
initial['1.3.6.1.2.1.2.2.1.2.17']='wan0'
initial['1.3.6.1.2.1.2.2.1.7.17']='1'
initial['1.3.6.1.2.1.2.2.1.8.17']='1'
transport=.SnmpMemoryTransport~new(initial)
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('router-a',session,map)
call assertEqual 'router-a',router~name,'agent semantic alias'
call assertEqual 'Example Router',router~description,'agent description alias'
call assertEqual '12345',router~uptime,'agent uptime alias'
wan=router~interfaces[17]
call assertEqual 'wan0',wan~description,'row description alias'
call assertEqual 'up',wan~adminStatus,'row admin status alias'
call assertEqual 'up',wan~operStatus,'row oper status alias'
wan~adminStatus='down'
call assertEqual 'down',wan~ifAdminStatus,'alias setter routes to mapped property'
say 'PASS semantic aliases through UNKNOWN'
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
  return

::requires '../src/Snmp.cls'
