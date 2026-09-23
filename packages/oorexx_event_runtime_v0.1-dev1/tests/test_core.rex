source=.EventSource~new('DEVICES')
observer=.TestObserver~new
trigger=.TestTrigger~new

sub=source~on('DEVICE.ADDED',observer,'onAdded')
filter=.EventFilter~new('DEVICE.ADDED','DEVICES',.UsbPredicate~new)
trig=source~when(filter)~fire(trigger,'attach','ASYNC')

meta=.directory~new
meta['subsystem']='usb'
r=source~emit('DEVICE.ADDED','phone',meta)

if observer~count<>1 then call fail 'sync observer count'
if observer~last<>'phone' then call fail 'sync observer payload'
if sub~fireCount<>1 then call fail 'subscription fire count'
if trig~fireCount<>1 then call fail 'trigger fire count'
if r~messages~items<>1 then call fail 'expected one async Message object'
msg=r~messages[1]
msg~wait
if msg~hasError then call fail 'async trigger message error'
if trigger~count<>1 then call fail 'async trigger count'

trig~disable
source~emit('DEVICE.ADDED','tablet',meta)
if trigger~count<>1 then call fail 'disabled trigger fired'
if observer~count<>2 then call fail 'observer did not receive second event'

source~dispatcher~unregister(sub)
source~emit('DEVICE.ADDED','watch',meta)
if observer~count<>2 then call fail 'unregistered observer fired'

say 'EVENT RUNTIME CORE: OK'
exit 0

fail: procedure
  parse arg why
  say 'FAIL:' why
  exit 1

::class TestObserver
::attribute count get
::attribute last get
::method init
  expose count last
  count=0; last=.nil
::method onAdded
  expose count last
  use strict arg event
  count+=1; last=event~data

::class TestTrigger
::attribute count get
::method init
  expose count
  count=0
::method attach
  expose count
  use strict arg event
  count+=1

::class UsbPredicate
::method accepts
  use strict arg event
  return event~metadataValue('subsystem','')=='usb'

::requires "src/EventRuntime.cls"
