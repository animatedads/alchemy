parse source . . here
base=filespec('L',here)
map=.SnmpImplementationMapLoader~new~loadFile(base||'../maps/ietf_minimal.json')
initial=.directory~new
initial['1.3.6.1.2.1.2.2.1.8.17']='1'
transport=.SnmpMemoryTransport~new(initial)
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('router-a',session,map)
wan=router~ifTable[17]
sink=.Sink~new
wan~on('INTERFACE.LINK.DOWN',sink,'onDown')
wan~refresh('ifOperStatus')       -- baseline only
transport~inject('1.3.6.1.2.1.2.2.1.8.17','2')
wan~refresh('ifOperStatus')
if sink~count<>1 then do; say 'FAIL semantic event count' sink~count; exit 1; end
if sink~last~data~oldValue<>'up' | sink~last~data~newValue<>'down' then do; say 'FAIL semantic transition values'; exit 1; end
say 'PASS refresh -> semantic registered event'
exit 0

::class Sink
::attribute count get
::attribute last get
::method init
 expose count last
 count=0; last=.nil
::method onDown
 expose count last
 use strict arg event
 count+=1; last=event

::requires '../src/Snmp.cls'
