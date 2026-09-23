provider=.ObservationFakeProvider~new
monitor=.DeviceMonitor~new(provider,'DEVICE-OBSERVATION',8)
validation=.ObservationProtocol~validateObserver(monitor)
call assert validation~ok, 'Observation validates DeviceMonitor'
stream=.ObservationStream~new('device.events.local',monitor,8)
call assert monitor~start, 'monitor starts'
event=monitor~poll(0)
call assert event<>.nil, 'event emitted'
record=stream~publish('DEVICE_EVENT')
call assert record<>.nil, 'Observation record published'
call assert record~generation=1, 'Observation sees device generation'
call assert record~envelope~snapshot~event~kind='CHANGE', 'Observation retains device event snapshot'
say 'DEVICE RUNTIME OBSERVATION: OK'
exit 0

assert: procedure
  use arg condition,label
  if \condition then do
    say 'FAIL:' label
    exit 1
  end
  return

::class ObservationFakeProvider public inherit DeviceProvider
::method init
  expose emitted
  emitted=.false
::method providerId
  return 'fake-observation'
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
  dev=.DeviceIdentity~new('/devices/fake-observation','fake-observation','input','event0','/devices/fake-observation','/dev/input/event0','input')
  return .DeviceEvent~new(0,'CHANGE',dev,'fake-observation')
::method stop
  return .true

::requires 'DeviceRuntime.cls'
::requires 'Observation.cls'
