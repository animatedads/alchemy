parse source . . here
base=filespec('L',here)
map=.SnmpImplementationMapLoader~new~loadFile(base||'../maps/ietf_minimal.json')
initial=.directory~new
initial['1.3.6.1.2.1.1.5.0']='router-a'
transport=.SnmpMemoryTransport~new(initial)
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('router-a',session,map)
view=router~observation
check=.ObservationProtocol~validateObserver(view)
if \check~ok then do; say 'FAIL observation shape' check~code; exit 1; end
router~refresh('name')
stream=.ObservationStream~new('snmp.router-a',view,8)
r1=stream~publish('SNMP_STATE')
if r1~generation<>1 then do; say 'FAIL first generation' r1~generation; exit 1; end
transport~inject('1.3.6.1.2.1.1.5.0','router-b')
router~refresh('name')
r2=stream~publish('SNMP_STATE')
if r2~generation<>2 then do; say 'FAIL second generation' r2~generation; exit 1; end
if view~current~visibleText~pos('SYSNAME=router-b')==0 then do; say 'FAIL snapshot state'; exit 1; end
if view~back(1)==.nil then do; say 'FAIL retained previous snapshot'; exit 1; end
say 'PASS Observation v0.5 shape + retained SNMP snapshots'
exit 0

::requires '../src/Snmp.cls'
::requires 'Observation.cls'
