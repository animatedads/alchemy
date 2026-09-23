parse source . . here
base=filespec('L',here)
map=.SnmpImplementationMapLoader~new~loadFile(base||'../maps/ietf_minimal.json')
initial=.directory~new
initial['1.3.6.1.2.1.2.2.1.1.17']='17'
initial['1.3.6.1.2.1.2.2.1.2.17']='wan0'
initial['1.3.6.1.2.1.2.2.1.7.17']='1'
initial['1.3.6.1.2.1.2.2.1.8.17']='1'
transport=.SnmpMemoryTransport~new(initial)
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('router-a',session,map)
wan=router~ifTable[17]
call assertEqual 'wan0',wan~ifDescr,'table row dynamic getter'
call assertEqual 'up',wan~ifOperStatus,'enum decode'
wan~ifAdminStatus='down'
call assertEqual 'down',wan~ifAdminStatus,'enum encode/decode setter'
resolved=map~resolveOid('1.3.6.1.2.1.2.2.1.8.17')
call assertEqual 'ifOperStatus',resolved[1]~name,'instance OID definition resolution'
call assertEqual '17',resolved[2]~string,'instance OID index resolution'
say 'PASS table/index projection'
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected=['expected'] actual=['actual']'
    exit 1
  end
  return

::requires '../src/Snmp.cls'
