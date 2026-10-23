/* JSON-RPC Fabric dev2: length-framed streams over injected Socket Provider.
 * This class never constructs a raw socket. It does not load Socket Provider.
 * Socket Provider v0.1-dev14 endpoints expose recv(n), sendAll(bytes), close().
 * Private RPC wire protocol: eight uppercase ASCII hex length bytes + payload.
 * NOT a JSON-RPC framing standard. Peers must explicitly agree this framing.
 */

/** Strictly bounded framing. No allocation or read beyond declared limit. */
::class JsonRpcLengthFrame public
::method init
  expose maximum
  use strict arg maximum=1048576
  if \datatype(maximum,'W') | maximum<1 | maximum>4294967295 then
    raise syntax 93.900 additional('invalid frame maximum')

::method maximum
  expose maximum
  return maximum

::method write
  expose maximum
  use strict arg endpoint, payload
  n=payload~length
  if n<1 | n>maximum then raise syntax 93.900 additional('RPC frame size outside limit')
  header=right(d2x(n),8,'0')
  bytes=header || payload
  sent=endpoint~sendAll(bytes)
  if \datatype(sent,'W') then raise syntax 93.900 additional('RPC stream write failed')
  if sent<>bytes~length then raise syntax 93.900 additional('short RPC stream write')
  return n

::method read
  expose maximum
  use strict arg endpoint
  header=self~readExact(endpoint,8)
  if header==.nil then raise syntax 93.900 additional('truncated frame header')
  if verify(header,'0123456789ABCDEF')<>0 then raise syntax 93.900 additional('invalid frame header')
  n=x2d(header)
  if n<1 | n>maximum then raise syntax 93.900 additional('RPC frame exceeds limit')
  data=self~readExact(endpoint,n)
  if data==.nil then raise syntax 93.900 additional('truncated frame payload')
  return data

::method readExact private
  use strict arg endpoint, count
  data=''
  do while data~length<count
    chunk=endpoint~recv(count-data~length)
    if chunk==.nil then return .nil
    if \chunk~isA(.String) then return .nil
    if chunk=='' then return .nil
    if chunk~length>count-data~length then
      raise syntax 93.900 additional('stream read exceeded requested size')
    data=data || chunk
  end
  return data

/** One Socket Provider sender endpoint per call, no retry/replay or pooling. */
::class JsonRpcSocketTransport public
::method init
  expose provider logicalName frame
  use strict arg provider, logicalName, maximum=1048576
  if provider==.nil | \provider~hasMethod('SENDER') then
    raise syntax 93.900 additional('Socket Provider with sender(name) required')
  if logicalName=='' then raise syntax 93.900 additional('logical service name required')
  frame=.JsonRpcLengthFrame~new(maximum)

::method exchange
  expose provider logicalName frame
  use strict arg requestBytes
  endpoint=provider~sender(logicalName)
  if endpoint==.nil then raise syntax 93.900 additional('service sender unavailable')
  signal on syntax name failed
  sent=frame~write(endpoint,requestBytes)
  replyBytes=frame~read(endpoint)
  ignore=endpoint~close
  signal off syntax
  return replyBytes
failed:
  signal off syntax
  ignore=endpoint~close
  raise syntax 93.900 additional('RPC socket exchange failed; completion unknown')

::method send
  expose provider logicalName frame
  use strict arg notificationBytes
  endpoint=provider~sender(logicalName)
  if endpoint==.nil then raise syntax 93.900 additional('service sender unavailable')
  signal on syntax name failed
  sent=frame~write(endpoint,notificationBytes)
  ignore=endpoint~close
  signal off syntax
  return .true
failed:
  signal off syntax
  ignore=endpoint~close
  raise syntax 93.900 additional('RPC notification send failed; delivery unknown')

/** The application supplies a Socket Provider listener and explicit auth context.
 * Each call handles ONE accepted connection, synchronously, then closes it.
 * Deploy a bounded/concurrent supervisor outside this simple service.
 */
::class JsonRpcSocketServer public
::method init
  expose dispatcher frame
  use strict arg dispatcher, maximum=1048576
  frame=.JsonRpcLengthFrame~new(maximum)

::method serveOne
  expose dispatcher frame
  use strict arg listener, context=.nil
  endpoint=listener~accept
  if endpoint==.nil then return .false
  signal on syntax name failed
  inbound=frame~read(endpoint)
  outbound=dispatcher~handleText(inbound,context)
  if outbound\==.nil then sent=frame~write(endpoint,outbound)
  ignore=endpoint~close
  signal off syntax
  return .true
failed:
  signal off syntax
  ignore=endpoint~close
  return .false

::requires 'JsonRpcFabric.cls'
