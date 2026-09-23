parse source . . here
base=filespec('L',here)
map=.SnmpImplementationMapLoader~new~loadFile(base||'../maps/ietf_minimal.json')
transport=.SnmpMemoryTransport~new
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('router-a',session,map)
wan=router~ifTable[17]
sink=.Sink~new
wan~on('INTERFACE.LINK.DOWN',sink,'onDown')
varbinds=.SnmpVarBindSet~new
varbinds~addRaw('1.3.6.1.2.1.2.2.1.1.17','17',map)
varbinds~addRaw('1.3.6.1.2.1.2.2.1.8.17','2',map)
router~acceptNotification('1.3.6.1.6.3.1.1.5.3',varbinds)
if sink~count<>1 then do; say 'FAIL notification event count' sink~count; exit 1; end
if sink~last~data~notification~name<>'linkDown' then do; say 'FAIL notification identity'; exit 1; end
say 'PASS notification OID -> row event projection'
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
