first=.FakeAccepted~new('socket://one','ONE')
second=.FakeAccepted~new('socket://two','TWO')
listener=.FakeListener~new(41,.array~of(first,second))
adapter=.SocketListenerEventAdapter~new(listener,'qualification.socket')
sink=.Sink~new
reg=adapter~onAccepted(sink,'accepted')
call assert adapter~descriptor=41,'descriptor retained'
call assert adapter~drainReady=2,'two ready accepts drained'
call assert sink~events~items=2,'two events delivered'
call assert sink~events[1]~type='SOCKET.ACCEPTED','generic event type'
call assert sink~events[1]~sourceId='qualification.socket','source identity'
call assert sink~events[1]~data==first,'accepted object preserved by identity'
call assert sink~events[2]~data==second,'second object preserved by identity'
call assert sink~events[1]~metadataValue('descriptor')=41,'descriptor metadata'
call assert sink~events[1]~metadataValue('canonicalAddress')='socket://one','full address evidence'
call assert adapter~drainReady=0,'nonblocking empty drain'
call assert listener~closeCount=0,'adapter does not own listener lifetime'
say 'PASS SocketProvider -> Event Runtime object-preserving adapter'
exit 0

assert: procedure
  use strict arg ok,why
  if \ok then do; say 'FAIL' why; exit 1; end
  return

::class Sink
::method init
  expose events
  events=.array~new
::attribute events get
::method accepted
  expose events
  use strict arg event
  events~append(event)

::class FakeAddress
::method init
  expose value
  use strict arg value
::method canonical
  expose value
  return value

::class FakeAccepted
::method init
  expose address payload
  use strict arg addressText,payload
  address=.FakeAddress~new(addressText)
::attribute address get
::attribute payload get

::class FakeListener
::method init
  expose descriptorValue pending closeCount
  use strict arg descriptorArg,pendingArg
  descriptorValue=descriptorArg
  pending=pendingArg
  closeCount=0
::attribute closeCount get
::method descriptor
  expose descriptorValue
  return descriptorValue
::method tryAccept
  expose pending
  if pending~items=0 then return .nil
  return pending~remove(1)
::method waitReady
  expose pending
  use strict arg timeoutMilliseconds=0
  return pending~items>0
::method close
  expose closeCount
  closeCount+=1
  return 0

::requires "EventRuntime.cls"
::requires "SocketEventRuntimeAdapter.cls"
