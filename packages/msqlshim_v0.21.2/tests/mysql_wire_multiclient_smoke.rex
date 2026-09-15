/* msqlshim v0.05 - verify an idle client cannot block authentication of another client. */
root = arg(1)
if root = "" then root = "example/demo"
port = 3452
server = .MySQLWireServer~new(root, "127.0.0.1", port)
activity = server~start("serve")
call SysSleep 0.25

sock1 = connectAndAuthenticate(port, "first")
if sock1 == .nil then do
  say "FAIL first client authentication"
  server~stop
  exit 1
end
say "PASS first client authenticated and left idle"

/* sock1 is deliberately left connected and idle here. */
sock2 = connectAndAuthenticate(port, "second")
if sock2 == .nil then do
  say "FAIL second client authentication while first idle"
  sock1~close
  server~stop
  exit 1
end
say "PASS second client authenticated while first client idle"

call sendPacket sock2, 0, "0E"x
packet = readPacket(sock2)
if packet == .nil then do
  say "FAIL second client ping"
  sock1~close
  sock2~close
  server~stop
  exit 1
end
if packet["payload"]~substr(1,1) \= "00"x then do
  say "FAIL second client ping response"
  sock1~close
  sock2~close
  server~stop
  exit 1
end
say "PASS second client COM_PING"

call sendPacket sock2, 0, "01"x
sock2~close
call sendPacket sock1, 0, "01"x
sock1~close
server~stop
call SysSleep 0.1
say "MYSQL WIRE MULTICLIENT SMOKE PASS"
exit 0

connectAndAuthenticate: procedure
  use arg port, username
  sock = .Socket~new
  address = .InetAddress~new("127.0.0.1", port)
  if sock~connect(address) < 0 then return .nil
  packet = readPacket(sock)
  if packet == .nil then do
    sock~close
    return .nil
  end
  caps = 1 + 4 + 512 + 8192 + 32768 + 524288
  response = le32(caps) || le32(16777216) || d2c(45) || copies("00"x,23) ||,
             username || "00"x || "00"x || "mysql_native_password" || "00"x
  call sendPacket sock, 1, response
  packet = readPacket(sock)
  if packet == .nil then do
    sock~close
    return .nil
  end
  if packet["payload"]~substr(1,1) \= "00"x then do
    sock~close
    return .nil
  end
  return sock

sendPacket: procedure
  use arg sock, sequence, payload
  packet = le24(payload~length) || d2c(sequence // 256) || payload
  offset = 1
  do while offset <= packet~length
    sent = sock~send(packet~substr(offset))
    if sent == .nil then return 0
    if sent <= 0 then return 0
    offset += sent
  end
  return 1

readPacket: procedure
  use arg sock
  header = recvExact(sock, 4)
  if header == .nil then return .nil
  length = c2d(header~substr(1,1)) + c2d(header~substr(2,1))*256 + c2d(header~substr(3,1))*65536
  payload = recvExact(sock, length)
  if payload == .nil then return .nil
  packet = .table~new
  packet["sequence"] = c2d(header~substr(4,1))
  packet["payload"] = payload
  return packet

recvExact: procedure
  use arg sock, wanted
  if wanted = 0 then return ""
  data = ""
  do while data~length < wanted
    part = sock~recv(wanted - data~length)
    if part == .nil then return .nil
    if part = "" then return .nil
    data ||= part
  end
  return data

le24: procedure
  use arg number
  b1 = number // 256
  b2 = (number % 256) // 256
  b3 = (number % 65536) // 256
  return d2c(b1) || d2c(b2) || d2c(b3)

le32: procedure
  use arg number
  answer = ""
  n = number
  do 4
    answer ||= d2c(n // 256)
    n = n % 256
  end
  return answer

::requires "socket.cls"
::requires "src/MySQLWireServer.cls"
