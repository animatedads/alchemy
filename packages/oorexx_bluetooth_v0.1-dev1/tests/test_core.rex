call rxfuncadd 'sysloadfuncs','rexxutil','sysloadfuncs'; call sysloadfuncs

provider=.BluetoothMemoryProvider~new
provider~addAdapter(.BluetoothAdapter~new('hci0','Test Adapter',.true,.true))
identity=.BluetoothIdentity~new('dev-thermometer','memory-bluetooth','Kitchen thermometer','BLE','AA:BB:CC:DD:EE:FF','RANDOM')
provider~addDevice(identity)
chars=.array~new
c=.directory~new; c['uuid']='2a6e'; c['properties']=.array~of('READ','NOTIFY'); chars~append(c)
service=.directory~new; service['uuid']='181a'; service['characteristics']=chars
provider~defineServices('dev-thermometer',.array~of(service))

runtime=.BluetoothRuntime~new(provider)
dev=runtime~device('dev-thermometer')
if dev==.nil then call fail 'device lookup'
if dev~address<>'AA:BB:CC:DD:EE:FF' then call fail 'address projection'

temperature=dev~environmentalSensing~temperature
if temperature==.nil then call fail 'UNKNOWN semantic profile projection'
if temperature~uuid<>_btUuid('2a6e') then call fail 'temperature UUID'

sink=.Sink~new
reg=temperature~on(.BluetoothEvents~GATT_VALUE_CHANGED,sink,'changed')
if \temperature~notify(.true) then call fail 'notify enable'
provider~injectValue('dev-thermometer','181a','2a6e',2250)
runtime~poll(0)
if sink~count<>1 then call fail 'registered characteristic event'
if sink~lastValue<>2250 then call fail 'event value'
if temperature~cachedValue<>2250 then call fail 'cached value'

if \dev~connect then call fail 'connect control request'
runtime~poll(0)
if \dev~connected then call fail 'connected observation'
if \dev~pair then call fail 'pair control request'
runtime~poll(0)
if \dev~paired then call fail 'paired observation'

say 'BLUETOOTH CORE: OK'
exit 0

fail: procedure
  parse arg message
  say 'FAIL:' message
  exit 1

::class Sink
::attribute count get
::attribute lastValue get
::method init
  expose count lastValue
  count=0; lastValue=.nil
::method changed
  expose count lastValue
  use strict arg event
  count+=1
  lastValue=event~data~value

::requires '../src/Bluetooth.cls'
