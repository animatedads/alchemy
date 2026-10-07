/* LdapSocketIO.cls - exact-binary LDAP socket framing helpers. */

::class LdapSocketIO public
::method nativeHandle class
  use strict arg transport
  if transport == .nil then return .nil
  if transport~hasMethod("LDAPNATIVEHANDLE") then return transport~ldapNativeHandle
  if transport~hasMethod("RAW") then return transport~raw
  return transport
::method identity class
  use strict arg transport
  if transport == .nil then return "nil"
  if transport~hasMethod("ADDRESS") then do
    a=transport~address
    if a <> .nil then if a~hasMethod("CANONICAL") then return a~canonical
  end
  h=self~nativeHandle(transport)
  if h == .nil then return "nil"
  if h~hasMethod("STRING") then return h~string
  return h~class~id
::method waitReadable class
  use strict arg transport, timeoutSeconds=1
  if transport~hasMethod("LDAPWAITREADABLE") then return transport~ldapWaitReadable(timeoutSeconds)
  h=self~nativeHandle(transport)
  if h == .nil then return -1
  if \h~hasMethod("SELECT") then return -2
  reads=.array~of(h); writes=.array~new; excepts=.array~new
  return h~select(reads,writes,excepts,timeoutSeconds)
::method recvChunk class private
  use strict arg transport, wanted
  if transport~hasMethod("LDAPRECV") then return transport~ldapRecv(wanted)
  return transport~recv(wanted)
::method sendChunk class private
  use strict arg transport, bytes
  if transport~hasMethod("LDAPSEND") then return transport~ldapSend(bytes)
  return transport~send(bytes)
::method recvExact class
  use strict arg transport, wanted
  if wanted = 0 then return ""
  data = ""
  do while data~length < wanted
    part = self~recvChunk(transport, wanted - data~length)
    if part == .nil then return .nil
    if part = "" then return .nil
    data ||= part
  end
  return data
::method recvFrame class
  use strict arg transport
  first = self~recvExact(transport, 2)
  if first == .nil then return .nil
  firstLen = c2d(first~substr(2,1))
  header = first
  if firstLen < 128 then payloadLength = firstLen
  else do
    count = firstLen - 128
    if count = 0 | count > 4 then return .nil
    more = self~recvExact(transport, count)
    if more == .nil then return .nil
    header ||= more
    payloadLength = 0
    do i = 1 to count
      payloadLength = payloadLength * 256 + c2d(more~substr(i,1))
    end
  end
  payload = self~recvExact(transport, payloadLength)
  if payload == .nil then return .nil
  return header || payload
::method sendAll class
  use strict arg transport, bytes
  offset = 1
  do while offset <= bytes~length
    sent = self~sendChunk(transport, bytes~substr(offset))
    if sent == .nil then return .false
    if sent <= 0 then return .false
    offset += sent
  end
  return .true
::method close class
  use strict arg transport
  if transport~hasMethod("LDAPCLOSE") then do; transport~ldapClose; return; end
  transport~close

::requires "socket.cls"
