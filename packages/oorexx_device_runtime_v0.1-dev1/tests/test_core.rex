provider=.FakeDeviceProvider~new
monitor=.DeviceMonitor~new(provider,'TEST-MONITOR',8)
observer=.CollectingObserver~new
filter=.DeviceEventFilter~new(.array~of('ADD'),'USB')
sub=monitor~eventBus~subscribe(observer,filter)
action=.CountingAction~new
trigger=.DeviceTrigger~new('USB-ADD',action,filter)
monitor~eventBus~registerTrigger(trigger)

call assert monitor~start, 'monitor start'
event=monitor~poll(0)
call assert event<>.nil, 'event emitted'
call assert event~kind='ADD', 'event kind'
call assert event~device~subsystem='usb', 'subsystem'
call assert observer~count=1, 'subscription fired'
call assert action~count=1, 'trigger fired'
call assert trigger~fireCount=1, 'trigger count'
call assert monitor~generation=1, 'generation'
call assert monitor~snapshot~generation=1, 'snapshot generation'
call assert monitor~knownStateId='/devices/fake0', 'known state identity'

/* The monitor intentionally implements the Observation observer method set. */
required=.array~of('SESSIONID','TERMINALTYPE','DEVICENAME','SNAPSHOT','CURRENT','BACK','HISTORY','KNOWNSTATESTATUS','KNOWNSTATEID','KNOWNSTATEGENERATION','KNOWNSTATEHISTORY')
do m over required
  call assert monitor~hasMethod(m), 'observation seam 'm
end

say 'DEVICE RUNTIME CORE: OK'
exit 0

assert: procedure
  use arg condition,label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
  return

::class FakeDeviceProvider public inherit DeviceProvider
::method init
  expose emitted
  emitted=.false
::method providerId
  return 'fake'
::method enumerate
  use arg subsystem=''
  return .array~new
::method start
  use arg subsystem=''
  return .true
::method pollEvent
  expose emitted
  use arg timeout=0
  if emitted then return .nil
  emitted=.true
  props=.directory~new
  props['ID_VENDOR_ID']='1234'
  dev=.DeviceIdentity~new('/devices/fake0','fake','usb','fake0','/devices/fake0','/dev/fake0','usb_device',props)
  return .DeviceEvent~new(0,'ADD',dev,'fake')
::method stop
  return .true

::class CollectingObserver public
::attribute count get
::method init
  expose count
  count=0
::method onDeviceEvent
  expose count
  use arg event
  count+=1

::class CountingAction public
::attribute count get
::method init
  expose count
  count=0
::method onDeviceTrigger
  expose count
  use arg trigger,event
  count+=1

::requires 'DeviceRuntime.cls'
