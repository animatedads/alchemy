parse source . . here
base=filespec('L',here)
loader=.SnmpImplementationMapLoader~new
map=loader~loadFile(base||'../maps/ietf_minimal.json')
map~adopt(loader~loadFile(base||'../maps/example_vendor_sensor.json'))

values=.directory~new
values['1.3.6.1.2.1.1.1.0']='Demo router/sensor'
values['1.3.6.1.2.1.1.5.0']='edge-a'
values['1.3.6.1.2.1.2.2.1.1.17']='17'
values['1.3.6.1.2.1.2.2.1.2.17']='wan0'
values['1.3.6.1.2.1.2.2.1.7.17']='1'
values['1.3.6.1.2.1.2.2.1.8.17']='1'
values['1.3.6.1.4.1.99999.1.1.0']='72'

transport=.SnmpMemoryTransport~new(values)
session=.SnmpSession~new(transport,map)
router=.SnmpAgent~new('edge-a',session,map)

say 'Name:' router~name
say 'Description:' router~description

wan=router~interfaces[17]
say 'Interface:' wan~description 'state:' wan~operStatus

sink=.ExampleEvents~new
wan~on('linkDown',sink,'linkDown')
router~on('temperatureCritical',sink,'temperatureCritical')

/* Baselines are observations, not alerts. */
wan~refresh('operStatus')
router~refresh('temperatureCelsius')

transport~inject('1.3.6.1.2.1.2.2.1.8.17','2')
wan~refresh('operStatus')

transport~inject('1.3.6.1.4.1.99999.1.1.0','85')
router~refresh('temperatureCelsius')

exit 0

::class ExampleEvents
::method linkDown
  use strict arg event
  say 'link down:' event~sourceId
::method temperatureCritical
  use strict arg event
  say 'temperature critical:' event~data~newValue

::requires '../src/Snmp.cls'
