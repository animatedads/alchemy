parse source . . here
base=filespec('L',here)
map=.SnmpImplementationMapLoader~new~loadFile(base||'../maps/ietf_minimal.json')
transport=.SnmpMemoryTransport~new
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('router-a',session,map)
wan=router~interfaces[17]
varbinds=.SnmpVarBindSet~new
varbinds~addRaw('1.3.6.1.2.1.2.2.1.1.17','17',map)
varbinds~addRaw('1.3.6.1.2.1.2.2.1.8.17','2',map)
router~acceptNotification('linkDown',varbinds)
if wan~cached('operStatus')<>'down' then do; say 'FAIL notification did not seed row state'; exit 1; end
if wan~generation<1 then do; say 'FAIL notification state generation'; exit 1; end
say 'PASS notification evidence seeds managed state before semantic event'
exit 0

::requires '../src/Snmp.cls'
