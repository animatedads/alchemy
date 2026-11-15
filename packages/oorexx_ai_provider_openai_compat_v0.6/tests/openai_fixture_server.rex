argv = arg(1)
parse var argv portFile statusFile secretMarker
if portFile = "" | statusFile = "" | secretMarker = "" then exit 64
listener = .Socket~new("AF_INET", "SOCK_STREAM", 0)
if listener~errno \= 0 then call fail "SOCKET_CREATE"
ignore = listener~setOption("SO_REUSEADDR", 1)
if listener~bind(.InetAddress~new("127.0.0.1", 0)) = -1 then call fail "BIND"
if listener~listen(1) = -1 then call fail "LISTEN"
actual = listener~getSockName
if actual == .nil then call fail "SOCKNAME"
call writeText portFile, actual~port
client = listener~accept
if client == .nil then call fail "ACCEPT"
requestText = ""
headerEnd = 0
contentLength = 0
do forever
  chunk = client~recv(4096)
  if chunk == .nil then leave
  if chunk == "" then leave
  requestText = requestText || chunk
  if headerEnd = 0 then do
    headerEnd = pos("0d0a0d0a"x, requestText)
    if headerEnd > 0 then contentLength = findContentLength(left(requestText, headerEnd - 1))
  end
  if headerEnd > 0 then do
    bodyStart = headerEnd + 4
    bodyHave = requestText~length - bodyStart + 1
    if bodyHave >= contentLength then leave
  end
end

ok = .true
detail = "OK"
if requestText~pos("POST /v1/chat/completions HTTP/") = 0 then do; ok = .false; detail = "REQUEST_LINE"; end
if ok then if requestText~pos("Authorization: Bearer " || secretMarker) = 0 then do; ok = .false; detail = "AUTH"; end
if ok then if requestText~pos('"model":"fixture-model"') = 0 then do; ok = .false; detail = "MODEL"; end
if ok then if requestText~pos('"content":"hello provider"') = 0 then do; ok = .false; detail = "PROMPT"; end

if ok then do
  body = '{"id":"real-curl-1","model":"fixture-model-live","choices":[{"message":{"role":"assistant","content":"real curl says hello"},"finish_reason":"stop"}],"usage":{"prompt_tokens":2,"completion_tokens":4,"total_tokens":6}}'
  statusLine = "HTTP/1.1 200 OK"
end
else do
  body = '{"error":"fixture rejected request"}'
  statusLine = "HTTP/1.1 400 Bad Request"
end
responseText = statusLine || "0d0a"x || "Content-Type: application/json" || "0d0a"x || "Content-Length: " || body~length || "0d0a"x || "Connection: close" || "0d0a0d0a"x || body
offset = 1
do while offset <= responseText~length
  sent = client~send(substr(responseText, offset))
  if sent == .nil then leave
  if sent <= 0 then leave
  offset = offset + sent
end
ignore = client~close
ignore = listener~close
if ok then call writeText statusFile, "OK"
else call writeText statusFile, "FAIL " || detail
exit 0

findContentLength:
  procedure
  use arg headers
  crlf = "0d0a"x
  start = 1
  do forever
    e = pos(crlf, headers, start)
    if e = 0 then line = substr(headers, start)
    else line = substr(headers, start, e - start)
    colon = line~pos(":")
    if colon > 1 then do
      name = line~left(colon - 1)~strip~translate
      if name = "CONTENT-LENGTH" then do
        valueText = line~substr(colon + 1)~strip
        if datatype(valueText, "W") then return valueText
      end
    end
    if e = 0 then leave
    start = e + crlf~length
  end
  return 0

writeText:
  procedure
  use arg path, text
  s = .Stream~new(path)
  opened = s~open("WRITE REPLACE")
  if \opened~caselessEquals("READY:") then exit 65
  ignore = s~lineout(text)
  ignore = s~close
  return

fail:
  use arg message
  if statusFile \= "" then call writeText statusFile, "FAIL " || message
  exit 66

::requires "socket.cls"
