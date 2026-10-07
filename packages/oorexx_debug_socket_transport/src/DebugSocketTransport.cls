/*----------------------------------------------------------------------------*/
/* ooRexx Debug Socket Transport.                                              */
/*                                                                            */
/* This class consumes an estate Socket object. It does not create TCP, QUIC, */
/* XTP, TLS or Unix sockets and never flattens SocketAddress into strings.     */
/* SocketSelector / SocketProvider own family selection and acquisition.       */
/*----------------------------------------------------------------------------*/

::class DebugSocketTransportBuild public
::constant RELEASE "0.1-dev7"
::constant API "debug.socket.transport/0.1"

::class DebugSocketTransport public
::constant OWNED "OWNED"
::constant BORROWED "BORROWED"
::constant OPEN "OPEN"
::constant READ_CLOSED "READ_CLOSED"
::constant WRITE_CLOSED "WRITE_CLOSED"
::constant CLOSED "CLOSED"
::attribute socket get
::attribute stream get
::attribute address get
::attribute state get
::attribute closePolicy get

::method init
  expose socket stream address state closePolicy readClosed writeClosed
  use strict arg socketArg,addressArg=.nil,closePolicyArg='OWNED',streamArg=.nil
  if socketArg==.nil then raise syntax 93.900 array('DebugSocketTransport requires a Socket object')
  cp=closePolicyArg~upper
  if cp<>'OWNED' & cp<>'BORROWED' then raise syntax 93.900 array('close policy must be OWNED or BORROWED',closePolicyArg)
  socket=socketArg
  if streamArg==.nil then stream=socketArg
  else stream=streamArg
  address=addressArg
  closePolicy=cp
  readClosed=.false
  writeClosed=.false
  state='OPEN'

/* Preserve the exact SocketAddress object selected by the estate resolver. */
::method socketAddress
  expose address
  return address

/* Preserve the exact Socket object, including provider/family-specific APIs. */
::method socketObject
  expose socket
  return socket

/* The byte-stream object used for READ/WRITE/PUMP/CLOSE delegation. */
::method streamObject
  expose stream
  return stream

/*
 * Convenience handoff for estate Socket objects which expose their selected
 * address object directly. The address object is retained by identity; it is
 * never reconstructed or projected into host/port primitives.
 */
::method fromSelectedSocket class
  use strict arg selectedSocket,closePolicyArg='BORROWED'
  if selectedSocket==.nil then raise syntax 93.900 array('fromSelectedSocket requires a Socket object')
  addressArg=.nil
  if selectedSocket~hasMethod('SOCKETADDRESS') then addressArg=selectedSocket~socketAddress
  else if selectedSocket~hasMethod('ADDRESS') then addressArg=selectedSocket~address
  return self~new(selectedSocket,addressArg,closePolicyArg)

/*
 * Inbound handoff for a Socket already accepted by an estate listener. The
 * listener remains the accept/selection authority. No listener, family or
 * carrier API is recreated here. If the caller already has the peer/address
 * object returned by the provider it may pass that exact object explicitly.
 */

/*
 * Handoff from the estate SocketStreamAdapter introduced by SocketProvider.
 * The adapter is only the byte-stream/lifecycle view; the complete underlying
 * Socket and SocketAddress objects remain available by identity.  This method
 * is deliberately direction-neutral: it can represent either a selector-
 * produced outbound socket or a listener-accepted inbound socket.
 */
::method fromSocketStreamAdapter class
  use strict arg adapter,socketArg=.nil,addressArg=.nil,closePolicyArg='BORROWED'
  if adapter==.nil then raise syntax 93.900 array('fromSocketStreamAdapter requires an adapter object')

  if socketArg==.nil then do
    if adapter~hasMethod('SOCKETOBJECT') then socketArg=adapter~socketObject
    else if adapter~hasMethod('SOCKET') then socketArg=adapter~socket
  end
  if socketArg==.nil then socketArg=adapter

  if addressArg==.nil then do
    if adapter~hasMethod('SOCKETADDRESS') then addressArg=adapter~socketAddress
    else if adapter~hasMethod('ADDRESS') then addressArg=adapter~address
    else if socketArg~hasMethod('SOCKETADDRESS') then addressArg=socketArg~socketAddress
    else if socketArg~hasMethod('ADDRESS') then addressArg=socketArg~address
  end

  return self~new(socketArg,addressArg,closePolicyArg,adapter)

::method fromAcceptedSocket class
  use strict arg acceptedSocket,addressArg=.nil,closePolicyArg='BORROWED'
  if acceptedSocket==.nil then raise syntax 93.900 array('fromAcceptedSocket requires a Socket object')
  if addressArg==.nil then do
    if acceptedSocket~hasMethod('SOCKETADDRESS') then addressArg=acceptedSocket~socketAddress
    else if acceptedSocket~hasMethod('ADDRESS') then addressArg=acceptedSocket~address
  end
  return self~new(acceptedSocket,addressArg,closePolicyArg)

::method write
  expose stream
  use strict arg bytes
  if \self~canWrite then return .false
  if \stream~hasMethod('WRITE') then raise syntax 93.900 array('Selected socket stream has no WRITE method')
  /* Provider/adapter errors deliberately propagate unchanged to the caller. */
  return stream~write(bytes)

/*
 * Socket READ remains authoritative. No protocol address or carrier data is
 * reinterpreted here. A Socket implementation may be TCP, QUIC, XTP, TLS,
 * Unix-domain, or another provider selected elsewhere.
 */
::method read
  expose stream
  use strict arg count
  if count<0 then raise syntax 93.900 array('read count must not be negative',count)
  if \self~canRead then return .nil
  if \stream~hasMethod('READ') then raise syntax 93.900 array('Selected socket stream has no READ method')
  /* Provider EOF/errors remain provider semantics; the debugger does not map them. */
  return stream~read(count)

/* Optional event/poll integration without inventing a second socket API. */
::method pump
  expose stream
  use strict arg timeoutMs=0
  if timeoutMs<0 then raise syntax 93.900 array('pump timeout must not be negative',timeoutMs)
  if \self~isOpen then return .false
  if stream~hasMethod('PUMP') then return stream~pump(timeoutMs)
  if stream~hasMethod('POLL') then return stream~poll(timeoutMs)
  return .true

/*
 * Half-close first closes the debug view in that direction. For an OWNED
 * socket, a matching provider shutdown method is delegated when available.
 * A BORROWED view never mutates the shared provider socket merely because one
 * debugger has finished one direction of traffic.
 */
::method shutdownRead
  expose stream closePolicy readClosed
  if readClosed then return .true
  if closePolicy='OWNED' & stream~hasMethod('SHUTDOWNREAD') then do
    if \stream~shutdownRead then return .false
  end
  readClosed=.true
  self~refreshState
  return .true

::method shutdownWrite
  expose stream closePolicy writeClosed
  if writeClosed then return .true
  if closePolicy='OWNED' & stream~hasMethod('SHUTDOWNWRITE') then do
    if \stream~shutdownWrite then return .false
  end
  writeClosed=.true
  self~refreshState
  return .true

/*
 * OWNED means this view is responsible for closing the selected Socket.
 * BORROWED means close only releases the debug view. An OWNED close failure
 * does not falsely report CLOSED; provider failure is visible to the caller.
 */
::method close
  expose stream state closePolicy readClosed writeClosed
  if state='CLOSED' then return .true
  if closePolicy='OWNED' then do
    if \stream~hasMethod('CLOSE') then raise syntax 93.900 array('Owned socket stream has no CLOSE method')
    ok=stream~close
    if \ok then return .false
  end
  readClosed=.true
  writeClosed=.true
  state='CLOSED'
  return .true

::method canRead
  expose readClosed state
  return state<>'CLOSED' & \readClosed

::method canWrite
  expose writeClosed state
  return state<>'CLOSED' & \writeClosed

::method isOpen
  expose state
  return state<>'CLOSED'

::method ownsSocket
  expose closePolicy
  return closePolicy='OWNED'

::method refreshState private
  expose state readClosed writeClosed
  if readClosed & writeClosed then state='CLOSED'
  else if readClosed then state='READ_CLOSED'
  else if writeClosed then state='WRITE_CLOSED'
  else state='OPEN'
  return state


/*----------------------------------------------------------------------------*/
/* JDWP over an already-selected Socket.                                       */
/*                                                                            */
/* JDWP owns only framing/handshake. The Socket owns transport semantics.      */
/*----------------------------------------------------------------------------*/

::class JdwpSocketTransport public subclass DebugSocketTransport
::method performHandshake
  if \self~write(.JdwpProtocol~HANDSHAKE) then return .false
  got=self~readExactly(.JdwpProtocol~HANDSHAKE~length)
  if got==.nil then return .false
  return got==.JdwpProtocol~HANDSHAKE

::method readExactly
  use strict arg count
  if count<0 then raise syntax 93.900 array('readExactly count must not be negative',count)
  if count=0 then return ''
  out=''
  do while out~length<count
    part=self~read(count-out~length)
    if part==.nil then return .nil
    if part~length=0 then return .nil
    out=out||part
  end
  return out

::method readPacket
  use strict arg timeoutMs=0
  if timeoutMs<0 then raise syntax 93.900 array('readPacket timeout must not be negative',timeoutMs)
  /* Timeout/poll policy belongs to the Socket. Pump only when the caller asks. */
  if timeoutMs>0 then do
    if \self~pump(timeoutMs) then return .nil
  end
  header=self~readExactly(4)
  if header==.nil then return .nil
  n=.JdwpPacketCodec~packetLength(header)
  if n<11 then raise syntax 93.900 array('JDWP packet length shorter than header',n)
  rest=self~readExactly(n-4)
  if rest==.nil then return .nil
  return .JdwpPacketCodec~decode(header||rest)

::requires "JdwpWire.cls"
