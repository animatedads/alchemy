provider=.BluetoothMemoryProvider~new
provider~addDevice(.BluetoothIdentity~new('kitchen','memory-bluetooth','Kitchen thermometer','BLE'))
chars=.array~new; c=.directory~new; c['uuid']='2a6e'; c['properties']=.array~of('READ','NOTIFY'); chars~append(c)
s=.directory~new; s['uuid']='181a'; s['characteristics']=chars
provider~defineServices('kitchen',.array~of(s))
bluetooth=.BluetoothRuntime~new(provider)
thermometer=bluetooth~device('kitchen')
temperature=thermometer~environmentalSensing~temperature
temperature~on(.BluetoothEvents~GATT_VALUE_CHANGED,.Display~new,'temperatureChanged')
temperature~notify(.true)
provider~injectValue('kitchen','181a','2a6e',21.75)
bluetooth~poll

::class Display
::method temperatureChanged
  use strict arg event
  say 'Temperature changed to' event~data~value
::requires '../src/Bluetooth.cls'
