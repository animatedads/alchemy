/* ooRexx SocketProvider -> Event Runtime adapter v0.1-dev1.
 *
 * Event Runtime owns registration/dispatch. SocketProvider owns descriptor and
 * nonblocking accept mechanics. This adapter is invoked after a descriptor is
 * known ready (or via the bounded waitAndDrain convenience method).
 */

::class SocketEventRuntimeAdapterBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "socket.event.runtime.adapter/0.1"

::class SocketListenerEventAdapter public
::attribute listener get
::attribute source get
::attribute sourceId get
::attribute descriptor get

::method init
  expose listener source sourceId descriptor
  use strict arg listenerArg, sourceIdArg="", dispatcherArg=.nil
  if listenerArg==.nil then raise syntax 93.900 array('listener is required')
  listener=listenerArg
  descriptor=listener~descriptor
  if descriptor<0 then raise syntax 93.900 array('listener does not expose a schedulable descriptor')
  sourceId=sourceIdArg~string
  if sourceId="" then sourceId='socket-descriptor:'||descriptor
  source=.EventSource~new(sourceId,dispatcherArg)

::method onAccepted
  expose source
  use strict arg target,messageName,delivery='SYNC'
  sourceRef=source
  guard off
  return sourceRef~on('SOCKET.ACCEPTED',target,messageName,delivery)

::method when
  expose source
  use strict arg filter
  sourceRef=source
  guard off
  return sourceRef~when(filter)

::method drainReady
  expose listener source descriptor
  use strict arg maxEvents=64
  maxEvents=maxEvents+0
  if maxEvents<1 then return 0
  listenerRef=listener
  sourceRef=source
  descriptorValue=descriptor
  /* Provider calls and Event Runtime callbacks must not execute while this
     adapter's guard is held. */
  guard off
  count=0
  do while count<maxEvents
    accepted=listenerRef~tryAccept
    if accepted==.nil then leave
    metadata=.directory~new
    metadata['descriptor']=descriptorValue
    if accepted~hasMethod('ADDRESS') then do
      address=accepted~address
      if address<>.nil then do
        metadata['address']=address
        if address~hasMethod('CANONICAL') then metadata['canonicalAddress']=address~canonical
      end
    end
    sourceRef~emit('SOCKET.ACCEPTED',accepted,metadata)
    count+=1
  end
  return count

::method waitAndDrain
  expose listener
  use strict arg timeoutMilliseconds=0,maxEvents=64
  listenerRef=listener
  guard off
  if \listenerRef~waitReady(timeoutMilliseconds) then return 0
  return self~drainReady(maxEvents)

/* Registry for multiple already-created adapters.
 * It does not poll/select descriptors and does not own listener lifetime.
 */
::class SocketDescriptorSet public
::method init
  expose adapters
  adapters=.directory~new

::method add guarded
  expose adapters
  use strict arg adapter
  if adapter==.nil then raise syntax 93.900 array('adapter is required')
  key=adapter~descriptor~string
  if adapters~hasIndex(key) then raise syntax 93.900 array('descriptor already registered: '||key)
  adapters[key]=adapter
  return adapter

::method remove guarded
  expose adapters
  use strict arg descriptor
  key=(descriptor+0)~string
  if \adapters~hasIndex(key) then return .false
  adapters~remove(key)
  return .true

::method adapterFor guarded
  expose adapters
  use strict arg descriptor
  key=(descriptor+0)~string
  if \adapters~hasIndex(key) then return .nil
  return adapters[key]

::method descriptors guarded
  expose adapters
  out=.array~new
  do key over adapters
    out~append(adapters[key]~descriptor)
  end
  return out

::method dispatchReady guarded
  expose adapters
  use strict arg descriptor,maxEvents=64
  key=(descriptor+0)~string
  if \adapters~hasIndex(key) then return -1
  adapter=adapters[key]
  /* Do not hold registry guard while provider or application callbacks run. */
  guard off
  return adapter~drainReady(maxEvents)

::requires "EventRuntime.cls"
