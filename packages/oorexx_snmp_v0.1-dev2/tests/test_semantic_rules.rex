parse source . . here
base=filespec('L',here)
loader=.SnmpImplementationMapLoader~new
map=loader~loadFile(base||'../maps/ietf_minimal.json')
map~adopt(loader~loadFile(base||'../maps/example_vendor_sensor.json'))
initial=.directory~new
initial['1.3.6.1.4.1.99999.1.1.0']='70'
transport=.SnmpMemoryTransport~new(initial)
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('sensor-a',session,map)
sink=.Sink~new
router~on('temperatureCritical',sink,'critical')
router~when('temperatureRecovered')~fire(sink,'recovered','SYNC')
router~refresh('temperatureCelsius')
transport~inject('1.3.6.1.4.1.99999.1.1.0','85')
router~refresh('temperatureCelsius')
if sink~criticalCount<>1 then do; say 'FAIL critical edge count' sink~criticalCount; exit 1; end
transport~inject('1.3.6.1.4.1.99999.1.1.0','90')
router~refresh('temperatureCelsius')
if sink~criticalCount<>1 then do; say 'FAIL repeated critical event'; exit 1; end
transport~inject('1.3.6.1.4.1.99999.1.1.0','75')
router~refresh('temperatureCelsius')
if sink~recoveredCount<>1 then do; say 'FAIL recovery edge count' sink~recoveredCount; exit 1; end
say 'PASS map-defined threshold semantics + named event registration'
exit 0

::class Sink
::attribute criticalCount get
::attribute recoveredCount get
::method init
  expose criticalCount recoveredCount
  criticalCount=0; recoveredCount=0
::method critical
  expose criticalCount
  use strict arg event
  criticalCount+=1
::method recovered
  expose recoveredCount
  use strict arg event
  recoveredCount+=1

::requires '../src/Snmp.cls'
