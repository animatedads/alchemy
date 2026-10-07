parse source . . here
call directory filespec('L',here)

/* The address is deliberately an object. Identity must survive the seam. */
address=.FakeSocketAddress~new('peer-ED209D','QUIC')
socket=.FakeSocket~new
transport=.DebugSocketTransport~new(socket,address)

if transport~socketObject \== socket then call fail 'Socket object was flattened/replaced'
if transport~socketAddress \== address then call fail 'SocketAddress object was flattened/replaced'
if transport~socketAddress~peerId<>'peer-ED209D' then call fail 'SocketAddress data lost'
if transport~socketAddress~family<>'QUIC' then call fail 'Socket family data lost'
if \transport~ownsSocket then call fail 'default close policy must preserve dev3 OWNED behaviour'

if \transport~write('ABC') then call fail 'socket write failed'
if socket~lastWrite<>'ABC' then call fail 'write did not delegate to Socket object'
socket~queueRead('DEFG')
if transport~read(2)<>'DE' then call fail 'first socket read wrong'
if transport~read(2)<>'FG' then call fail 'second socket read wrong'

/* JDWP is layered over the same Socket object; it does not acquire transport. */
jdwpSocket=.FakeSocket~new
jdwp=.JdwpSocketTransport~new(jdwpSocket,address)
jdwpSocket~queueRead(.JdwpProtocol~HANDSHAKE)
if \jdwp~performHandshake then call fail 'JDWP socket handshake failed'
if jdwp~socketObject \== jdwpSocket then call fail 'JDWP replaced Socket object'
if jdwp~socketAddress \== address then call fail 'JDWP replaced SocketAddress object'

if \transport~close then call fail 'close failed'
if socket~closed<>.true then call fail 'OWNED close did not delegate to Socket object'
if transport~isOpen then call fail 'transport still reports open'

/* A borrowed view must never close the provider/caller-owned socket. */
borrowedSocket=.FakeSocket~new
borrowed=.DebugSocketTransport~new(borrowedSocket,address,'BORROWED')
if borrowed~ownsSocket then call fail 'BORROWED transport reports ownership'
if \borrowed~close then call fail 'borrowed close failed'
if borrowedSocket~closed then call fail 'BORROWED transport closed caller-owned Socket'
if borrowed~isOpen then call fail 'borrowed transport still reports open'


/* Estate handoff may obtain the address directly from the selected Socket. */
selectedAddress=.FakeSocketAddress~new('peer-XTP','XTP')
selected=.FakeSocket~new(selectedAddress)
selectedView=.DebugSocketTransport~fromSelectedSocket(selected)
if selectedView~socketObject \== selected then call fail 'selected Socket identity lost'
if selectedView~socketAddress \== selectedAddress then call fail 'selected SocketAddress identity lost'
if selectedView~ownsSocket then call fail 'selector handoff must default BORROWED'

/* Listener accept handoff is symmetric with outbound selection. */
acceptedAddress=.FakeSocketAddress~new('peer-accepted','QUIC')
accepted=.FakeSocket~new(acceptedAddress)
acceptedView=.DebugSocketTransport~fromAcceptedSocket(accepted)
if acceptedView~socketObject \== accepted then call fail 'accepted Socket identity lost'
if acceptedView~socketAddress \== acceptedAddress then call fail 'accepted SocketAddress identity lost'
if acceptedView~ownsSocket then call fail 'accepted Socket handoff must default BORROWED'

/* An acceptor may supply the exact peer/address object separately. */
providerSocket=.FakeSocket~new
providerAddress=.FakeSocketAddress~new('peer-provider-object','XTP')
providerView=.DebugSocketTransport~fromAcceptedSocket(providerSocket,providerAddress)
if providerView~socketObject \== providerSocket then call fail 'accepted provider Socket replaced'
if providerView~socketAddress \== providerAddress then call fail 'explicit accepted address object replaced'
if providerView~socketAddress~family<>'XTP' then call fail 'accepted provider address data lost'

/* JDWP inherits the same class-level handoff rather than acquiring a socket. */
acceptedJdwpSocket=.FakeSocket~new(acceptedAddress)
acceptedJdwp=.JdwpSocketTransport~fromAcceptedSocket(acceptedJdwpSocket,acceptedAddress)
if acceptedJdwp~socketObject \== acceptedJdwpSocket then call fail 'JDWP accepted Socket identity lost'
if acceptedJdwp~socketAddress \== acceptedAddress then call fail 'JDWP accepted address identity lost'

/* Estate SocketStreamAdapter handoff keeps BOTH object layers intact. */
adaptAddress=.FakeSocketAddress~new('peer-adapter','XTP')
adaptSocket=.FakeSocket~new(adaptAddress)
adapter=.FakeSocketStreamAdapter~new(adaptSocket,adaptAddress)
adaptView=.DebugSocketTransport~fromSocketStreamAdapter(adapter)
if adaptView~streamObject \== adapter then call fail 'SocketStreamAdapter identity lost'
if adaptView~socketObject \== adaptSocket then call fail 'underlying Socket identity lost through adapter'
if adaptView~socketAddress \== adaptAddress then call fail 'SocketAddress identity lost through adapter'
if adaptView~ownsSocket then call fail 'adapter handoff must default BORROWED'
adapter~queueRead('AD')
if adaptView~read(2)<>'AD' then call fail 'adapter READ path not used'
if \adaptView~write('APTER') then call fail 'adapter WRITE path failed'
if adapter~lastWrite<>'APTER' then call fail 'adapter WRITE not delegated'
if adaptSocket~lastWrite<>'' then call fail 'debugger bypassed adapter and wrote underlying Socket directly'
if \adaptView~pump(1) then call fail 'adapter PUMP path failed'
if \adaptView~close then call fail 'borrowed adapter view close failed'
if adapter~closed then call fail 'BORROWED debug view closed estate adapter'
if adaptSocket~closed then call fail 'BORROWED adapter view closed underlying Socket'

/* Ownership transfer targets the adapter lifecycle, not a hidden protocol API. */
ownedAdaptSocket=.FakeSocket~new(adaptAddress)
ownedAdapter=.FakeSocketStreamAdapter~new(ownedAdaptSocket,adaptAddress)
ownedAdaptView=.DebugSocketTransport~fromSocketStreamAdapter(ownedAdapter,.nil,.nil,'OWNED')
if \ownedAdaptView~close then call fail 'OWNED adapter close failed'
if \ownedAdapter~closed then call fail 'OWNED close did not delegate to SocketStreamAdapter'
if \ownedAdaptSocket~closed then call fail 'adapter did not perform its provider-owned close'

/* Half-close is view-local for BORROWED sockets. */
shared=.FakeSocket~new(selectedAddress)
view=.DebugSocketTransport~new(shared,selectedAddress,'BORROWED')
if \view~shutdownWrite then call fail 'borrowed shutdownWrite failed'
if view~state<>'WRITE_CLOSED' | view~canWrite then call fail 'write half-close state wrong'
if \view~canRead then call fail 'write half-close incorrectly closed read side'
if shared~writeShutdown then call fail 'borrowed half-close mutated shared Socket'
if view~write('NO') then call fail 'write succeeded after write half-close'
shared~queueRead('OK')
if view~read(2)<>'OK' then call fail 'read failed after write half-close'
if \view~shutdownRead then call fail 'borrowed shutdownRead failed'
if view~state<>'CLOSED' | view~isOpen then call fail 'two half-closes did not close view'
if shared~readShutdown then call fail 'borrowed read half-close mutated shared Socket'

/* OWNED half-close delegates only when the Socket exposes those operations. */
ownedHalf=.FakeSocket~new(selectedAddress)
ownedView=.DebugSocketTransport~new(ownedHalf,selectedAddress,'OWNED')
if \ownedView~shutdownRead then call fail 'owned shutdownRead failed'
if \ownedHalf~readShutdown then call fail 'owned shutdownRead not delegated'
if ownedView~state<>'READ_CLOSED' then call fail 'owned read half-close state wrong'
if \ownedView~shutdownWrite then call fail 'owned shutdownWrite failed'
if \ownedHalf~writeShutdown then call fail 'owned shutdownWrite not delegated'
if ownedView~state<>'CLOSED' then call fail 'owned two half-closes did not close view'

/* Failed OWNED close must not lie about transport state. */
failing=.FakeSocket~new(selectedAddress)
failing~failClose=.true
failingView=.DebugSocketTransport~new(failing,selectedAddress,'OWNED')
if failingView~close then call fail 'failing Socket close reported success'
if \failingView~isOpen | failingView~state<>'OPEN' then call fail 'failed close falsely reported CLOSED'

say 'DEBUG SOCKET OBJECT SEAM: OK'
exit 0

fail: procedure
  parse arg m
  say 'FAIL:' m
  exit 1

::class FakeSocketAddress
::attribute peerId get
::attribute family get
::method init
  expose peerId family
  use strict arg peerIdArg,familyArg
  peerId=peerIdArg
  family=familyArg

::class FakeSocket
::attribute lastWrite get
::attribute closed get
::attribute address get
::attribute readShutdown get
::attribute writeShutdown get
::attribute failClose
::method init
  expose lastWrite closed incoming address readShutdown writeShutdown failClose
  use strict arg addressArg=.nil
  lastWrite=''
  closed=.false
  incoming=''
  address=addressArg
  readShutdown=.false
  writeShutdown=.false
  failClose=.false
::method socketAddress
  expose address
  return address
::method write
  expose lastWrite closed
  use strict arg bytes
  if closed then return .false
  lastWrite=bytes
  return .true
::method queueRead
  expose incoming
  use strict arg bytes
  incoming=incoming||bytes
  return self
::method read
  expose incoming closed
  use strict arg count
  if closed then return .nil
  if incoming~length=0 then return .nil
  n=count
  if n>incoming~length then n=incoming~length
  out=substr(incoming,1,n)
  incoming=substr(incoming,n+1)
  return out
::method pump
  expose closed incoming
  use strict arg timeoutMs=0
  if closed then return .false
  return incoming~length>0
::method shutdownRead
  expose readShutdown closed
  if closed then return .false
  readShutdown=.true
  return .true
::method shutdownWrite
  expose writeShutdown closed
  if closed then return .false
  writeShutdown=.true
  return .true
::method close
  expose closed failClose
  if failClose then return .false
  closed=.true
  return .true

::class FakeSocketStreamAdapter
::attribute socket get
::attribute address get
::attribute lastWrite get
::attribute closed get
::method init
  expose socket address incoming lastWrite closed
  use strict arg socketArg,addressArg
  socket=socketArg
  address=addressArg
  incoming=''
  lastWrite=''
  closed=.false
::method socketObject
  expose socket
  return socket
::method socketAddress
  expose address
  return address
::method queueRead
  expose incoming
  use strict arg bytes
  incoming=incoming||bytes
  return self
::method read
  expose incoming closed
  use strict arg count
  if closed then return .nil
  if incoming~length=0 then return .nil
  n=count
  if n>incoming~length then n=incoming~length
  out=substr(incoming,1,n)
  incoming=substr(incoming,n+1)
  return out
::method write
  expose lastWrite closed
  use strict arg bytes
  if closed then return .false
  lastWrite=bytes
  return .true
::method pump
  expose closed
  use strict arg timeoutMs=0
  if closed then return .false
  return .true
::method close
  expose socket closed
  if closed then return .true
  if socket~hasMethod('CLOSE') then do
    if \socket~close then return .false
  end
  closed=.true
  return .true

::requires "DebugSocketTransport.cls"
