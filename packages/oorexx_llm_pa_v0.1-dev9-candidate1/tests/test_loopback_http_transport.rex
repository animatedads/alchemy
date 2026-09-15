/* Actual RxSock loopback HTTP exercise for the API Client-backed Gemma path. */
server = .FakeOllamaServer~new
port = server~start
baseUrl = "http://127.0.0.1:" || port
orch = .LlmPaOllamaOrchestrator~new("gemma2:2b", baseUrl)
verified = orch~verifyModel
call must verified, "loopback tags probe"
out = orch~runOnce("gemma2:2b", "Hello Gemma", 64)
call must out, "loopback completion"
call mustBool out~value~text = "Native API path works!", "completion content"
call mustBool out~value~model~caselessEquals("gemma2:2b"), "completion model"
call SysSleep 0.05
call mustBool server~handled = 2, "two HTTP requests handled"
say "PASS test_loopback_http_transport"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class FakeOllamaServer public
::attribute handled get
::method init
  expose handled
  handled = 0
::method start unguarded
  expose handled
  listener = .Socket~new("AF_INET", "SOCK_STREAM", "IPPROTO_TCP")
  ignore = listener~setOption("SO_REUSEADDR", 1)
  rc = listener~bind(.InetAddress~new("127.0.0.1", 0))
  if rc \= 0 then raise syntax 88.900 array("fixture bind failed", listener~errno)
  rc = listener~listen(4)
  if rc \= 0 then raise syntax 88.900 array("fixture listen failed", listener~errno)
  local = listener~getSockName
  port = local~port
  reply port
  do n = 1 to 2
    conn = listener~accept
    if conn == .nil then leave
    raw = self~readRequest(conn)
    parse var raw method target .
    if target = "/api/tags" then body = '{"models":[{"name":"gemma2:2b"}]}'
    else if target = "/v1/chat/completions" then body = '{"model":"gemma2:2b","choices":[{"message":{"role":"assistant","content":"Native API path works!"},"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":4}}'
    else body = '{"error":"unknown fixture path"}'
    crlf = "0d0a"x
    response = "HTTP/1.1 200 OK" || crlf || -
      "Content-Type: application/json" || crlf || -
      "Content-Length: " || body~length || crlf || -
      "Connection: close" || crlf || crlf || body
    ignore = conn~send(response)
    ignore = conn~close
    handled += 1
  end
  ignore = listener~close
  return

::method readRequest private
  use arg conn
  raw = ""
  headerEnd = 0
  wanted = 0
  crlf = "0d0a"x
  sep = "0d0a0d0a"x
  do forever
    chunk = conn~recv(16384)
    if chunk == .nil | chunk = "" then leave
    raw = raw || chunk
    if headerEnd = 0 then do
      headerEnd = raw~pos(sep)
      if headerEnd > 0 then do
        head = raw~left(headerEnd - 1)
        lines = head~makeArray(crlf)
        do i = 2 to lines~items
          line = lines[i]
          colon = line~pos(":")
          if colon > 1 then do
            name = line~left(colon - 1)~strip~lower
            value = line~substr(colon + 1)~strip
            if name = "content-length" & datatype(value, "W") then wanted = value + 0
          end
        end
      end
    end
    if headerEnd > 0 then do
      bodyLength = raw~length - (headerEnd + 3)
      if bodyLength >= wanted then leave
    end
  end
  return raw

::requires "LlmPaNativeOllama.cls"
