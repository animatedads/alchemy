root = arg(1)
if root = "" then root = "example/demo"
port = 3451
server = .MySQLWireServer~new(root, "127.0.0.1", port)
activity = server~start("serve")
call SysSleep 0.25

sock = .Socket~new
address = .InetAddress~new("127.0.0.1", port)
if sock~connect(address) < 0 then do
  say "FAIL connect errno=" || sock~errno
  server~stop
  exit 1
end

packet = readPacket(sock)
if packet == .nil then do
  say "FAIL no handshake"
  server~stop
  exit 1
end
if c2d(packet["payload"]~substr(1,1)) \= 10 then do
  say "FAIL wrong protocol version"
  server~stop
  exit 1
end
say "PASS handshake"

caps = 1 + 4 + 512 + 8192 + 32768 + 524288
response = le32(caps) || le32(16777216) || d2c(45) || copies("00"x,23) ||,
           "test" || "00"x || "00"x || "mysql_native_password" || "00"x
call sendPacket sock, 1, response
packet = readPacket(sock)
if packet == .nil then do
  say "FAIL auth OK"
  server~stop
  exit 1
end
if packet["payload"]~substr(1,1) \= "00"x then do
  say "FAIL auth OK"
  server~stop
  exit 1
end
say "PASS unauthenticated protocol session"

call sendPacket sock, 0, "03"x || "SELECT VERSION()"
packet = readPacket(sock)
if packet == .nil then do
  say "FAIL no result header"
  server~stop
  exit 1
end
if c2d(packet["payload"]~substr(1,1)) \= 1 then do
  say "FAIL column count"
  server~stop
  exit 1
end
column = readPacket(sock)
metaEnd = readPacket(sock)
row = readPacket(sock)
resultEnd = readPacket(sock)
if row == .nil then do
  say "FAIL no row"
  server~stop
  exit 1
end
rowPayload = row["payload"]
valueLength = c2d(rowPayload~substr(1,1))
value = rowPayload~substr(2, valueLength)
if value \= "5.7.44-NoSQLServer-ooRexx" then do
  say "FAIL version row:" value
  server~stop
  exit 1
end
say "PASS COM_QUERY text resultset:" value

call sendPacket sock, 0, "0E"x
packet = readPacket(sock)
if packet == .nil then do
  say "FAIL ping"
  server~stop
  exit 1
end
if packet["payload"]~substr(1,1) \= "00"x then do
  say "FAIL ping"
  server~stop
  exit 1
end
say "PASS COM_PING"

call sendPacket sock, 0, "03"x || "SELECT @@version"
header = readPacket(sock)
if header == .nil | c2d(header["payload"]~substr(1,1)) \= 1 then do
  say "FAIL SELECT @@version header"
  server~stop
  exit 1
end
column = readPacket(sock)
metaEnd = readPacket(sock)
row = readPacket(sock)
resultEnd = readPacket(sock)
if row == .nil then do
  say "FAIL SELECT @@version row"
  server~stop
  exit 1
end
rowPayload = row["payload"]
valueLength = c2d(rowPayload~substr(1,1))
value = rowPayload~substr(2, valueLength)
if value \= "5.7.44-NoSQLServer-ooRexx" then do
  say "FAIL SELECT @@version value:" value
  server~stop
  exit 1
end
say "PASS SELECT @@version"

call sendPacket sock, 0, "03"x || "SELECT @@sql_mode"
header = readPacket(sock)
column = readPacket(sock)
metaEnd = readPacket(sock)
row = readPacket(sock)
resultEnd = readPacket(sock)
if header == .nil | row == .nil then do
  say "FAIL SELECT @@sql_mode"
  server~stop
  exit 1
end
say "PASS SELECT @@sql_mode"

call sendPacket sock, 0, "03"x || "SET NAMES utf8mb4"
packet = readPacket(sock)
if packet == .nil then do
  say "FAIL SET NAMES utf8mb4"
  server~stop
  exit 1
end
if packet["payload"]~substr(1,1) \= "00"x then do
  say "FAIL SET NAMES utf8mb4"
  server~stop
  exit 1
end
say "PASS SET NAMES utf8mb4"

call sendPacket sock, 0, "03"x || "SHOW VARIABLES LIKE 'character_set_%'"
header = readPacket(sock)
if header == .nil | c2d(header["payload"]~substr(1,1)) \= 2 then do
  say "FAIL SHOW VARIABLES header"
  server~stop
  exit 1
end
col1 = readPacket(sock)
col2 = readPacket(sock)
metaEnd = readPacket(sock)
variableRows = 0
do forever
  item = readPacket(sock)
  if item == .nil then leave
  pld = item["payload"]
  if pld~substr(1,1) = "FE"x & pld~length < 9 then leave
  variableRows += 1
end
if variableRows < 4 then do
  say "FAIL SHOW VARIABLES LIKE character_set_% rows=" variableRows
  server~stop
  exit 1
end
say "PASS SHOW VARIABLES LIKE character_set_%"

call sendPacket sock, 0, "03"x || "SHOW STATUS LIKE 'Ssl_cipher'"
header = readPacket(sock)
if header == .nil | c2d(header["payload"]~substr(1,1)) \= 2 then do
  say "FAIL SHOW STATUS header"
  server~stop
  exit 1
end
col1 = readPacket(sock)
col2 = readPacket(sock)
metaEnd = readPacket(sock)
row = readPacket(sock)
resultEnd = readPacket(sock)
if row == .nil then do
  say "FAIL SHOW STATUS row"
  server~stop
  exit 1
end
rowPayload = row["payload"]
fieldLen = c2d(rowPayload~substr(1,1))
fieldName = rowPayload~substr(2, fieldLen)
if \fieldName~caselessEquals("Ssl_cipher") then do
  say "FAIL SHOW STATUS field:" fieldName
  server~stop
  exit 1
end
say "PASS SHOW STATUS LIKE Ssl_cipher"

call sendPacket sock, 0, "03"x || "SHOW DATABASES"
header = readPacket(sock)
if header == .nil | c2d(header["payload"]~substr(1,1)) \= 1 then do
  say "FAIL SHOW DATABASES header"
  server~stop
  exit 1
end
column = readPacket(sock)
metaEnd = readPacket(sock)
row = readPacket(sock)
resultEnd = readPacket(sock)
if row == .nil then do
  say "FAIL SHOW DATABASES row"
  server~stop
  exit 1
end
say "PASS SHOW DATABASES"

call sendPacket sock, 0, "03"x || "SHOW TABLES"
header = readPacket(sock)
if header == .nil | c2d(header["payload"]~substr(1,1)) \= 1 then do
  say "FAIL SHOW TABLES header"
  server~stop
  exit 1
end
column = readPacket(sock)
metaEnd = readPacket(sock)
foundCustomer = .false
do forever
  item = readPacket(sock)
  if item == .nil then leave
  pld = item["payload"]
  if pld~substr(1,1) = "FE"x & pld~length < 9 then leave
  n = c2d(pld~substr(1,1))
  if pld~substr(2,n)~caselessEquals("customer") then foundCustomer = .true
end
if \foundCustomer then do
  say "FAIL SHOW TABLES missing customer"
  server~stop
  exit 1
end
say "PASS SHOW TABLES"

call sendPacket sock, 0, "03"x || "DESCRIBE customer"
header = readPacket(sock)
if header == .nil | c2d(header["payload"]~substr(1,1)) \= 6 then do
  say "FAIL DESCRIBE header"
  server~stop
  exit 1
end
do 6
  column = readPacket(sock)
end
metaEnd = readPacket(sock)
row = readPacket(sock)
if row == .nil then do
  say "FAIL DESCRIBE row"
  server~stop
  exit 1
end
rowPayload = row["payload"]
fieldLen = c2d(rowPayload~substr(1,1))
fieldName = rowPayload~substr(2, fieldLen)
if fieldName \= "customer_id" then do
  say "FAIL DESCRIBE first field:" fieldName
  server~stop
  exit 1
end
do forever
  item = readPacket(sock)
  if item == .nil then leave
  pld = item["payload"]
  if pld~substr(1,1) = "FE"x & pld~length < 9 then leave
end
say "PASS DESCRIBE customer"

call sendPacket sock, 0, "03"x || "SHOW COLUMNS FROM customer"
header = readPacket(sock)
if header == .nil | c2d(header["payload"]~substr(1,1)) \= 6 then do
  say "FAIL SHOW COLUMNS header"
  server~stop
  exit 1
end
do 6
  column = readPacket(sock)
end
metaEnd = readPacket(sock)
row = readPacket(sock)
if row == .nil then do
  say "FAIL SHOW COLUMNS row"
  server~stop
  exit 1
end
rowPayload = row["payload"]
fieldLen = c2d(rowPayload~substr(1,1))
fieldName = rowPayload~substr(2, fieldLen)
if fieldName \= "customer_id" then do
  say "FAIL SHOW COLUMNS first field:" fieldName
  server~stop
  exit 1
end
do forever
  item = readPacket(sock)
  if item == .nil then leave
  pld = item["payload"]
  if pld~substr(1,1) = "FE"x & pld~length < 9 then leave
end
say "PASS SHOW COLUMNS FROM customer"

call sendPacket sock, 0, "03"x || "INSERT INTO customer (customer_id, name, email) VALUES (901, 'Wire User', 'wire@example.test')"
packet = readPacket(sock)
if packet == .nil then do
  say "FAIL wire INSERT"
  server~stop
  exit 1
end
if packet["payload"]~substr(1,1) \= "00"x then do
  say "FAIL wire INSERT"
  server~stop
  exit 1
end
say "PASS COM_QUERY mutation"

call sendPacket sock, 0, "03"x || "SELECT customer_id, name FROM customer WHERE customer_id = 901"
header = readPacket(sock)
if header == .nil then do
  say "FAIL database SELECT header"
  server~stop
  exit 1
end
if c2d(header["payload"]~substr(1,1)) \= 2 then do
  say "FAIL database SELECT header payload=" c2x(header["payload"])
  server~stop
  exit 1
end
col1 = readPacket(sock)
col2 = readPacket(sock)
metaEnd = readPacket(sock)
row = readPacket(sock)
resultEnd = readPacket(sock)
if row == .nil then do
  say "FAIL database SELECT row"
  server~stop
  exit 1
end
rowPayload = row["payload"]
len1 = c2d(rowPayload~substr(1,1))
value1 = rowPayload~substr(2,len1)
pos2 = 2 + len1
len2 = c2d(rowPayload~substr(pos2,1))
value2 = rowPayload~substr(pos2 + 1,len2)
if value1 \= "901" | value2 \= "Wire User" then do
  say "FAIL database SELECT values:" value1 value2
  server~stop
  exit 1
end
say "PASS NoSQLServer SQL over MySQL wire:" value1 value2

call sendPacket sock, 0, "03"x || "SELECT * FROM customer WHERE customer_id = 901"
header = readPacket(sock)
if header == .nil then do
  say "FAIL wildcard SELECT header"
  server~stop
  exit 1
end
if c2d(header["payload"]~substr(1,1)) \= 3 then do
  say "FAIL wildcard SELECT column count payload=" c2x(header["payload"])
  server~stop
  exit 1
end
do 3
  column = readPacket(sock)
end
metaEnd = readPacket(sock)
row = readPacket(sock)
resultEnd = readPacket(sock)
if row == .nil then do
  say "FAIL wildcard SELECT row"
  server~stop
  exit 1
end
rowPayload = row["payload"]
len1 = c2d(rowPayload~substr(1,1))
value1 = rowPayload~substr(2,len1)
if value1 \= "901" then do
  say "FAIL wildcard SELECT first value:" value1
  server~stop
  exit 1
end
say "PASS SELECT * result metadata and row framing"

call sendPacket sock, 0, "01"x
sock~close
server~stop
say "MYSQL WIRE SMOKE PASS"
exit 0

sendPacket: procedure
  use arg sock, seq, payload
  header = le24(payload~length) || d2c(seq)
  data = header || payload
  offset = 1
  do while offset <= data~length
    sent = sock~send(data~substr(offset))
    if sent <= 0 then return 0
    offset += sent
  end
  return 1

readPacket: procedure
  use arg sock
  header = recvExact(sock, 4)
  if header == .nil then return .nil
  len = c2d(header~substr(1,1)) + c2d(header~substr(2,1))*256 + c2d(header~substr(3,1))*65536
  payload = recvExact(sock, len)
  if payload == .nil then return .nil
  p = .table~new
  p["sequence"] = c2d(header~substr(4,1))
  p["payload"] = payload
  return p

recvExact: procedure
  use arg sock, wanted
  if wanted = 0 then return ""
  data = ""
  do while data~length < wanted
    part = sock~recv(wanted - data~length)
    if part == .nil | part == "" then return .nil
    data ||= part
  end
  return data

le24: procedure
  use arg n
  b0 = n // 256
  q = n % 256
  b1 = q // 256
  b2 = (q % 256) // 256
  return d2c(b0)||d2c(b1)||d2c(b2)

le32: procedure
  use arg n
  out = ""
  w = n
  do 4
    out ||= d2c(w // 256)
    w = w % 256
  end
  return out

::requires "src/MySQLWireServer.cls"
