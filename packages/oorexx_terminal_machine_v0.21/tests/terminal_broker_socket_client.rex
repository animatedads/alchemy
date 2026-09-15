parse arg port keyHex expectedMode
if expectedMode == "" then expectedMode = "VALID"
client = .TerminalBrokerLocalSocketClient~new(port, "AI_A", "k1", keyHex)
connected = client~connect
if expectedMode == "REJECT" then do
  if connected~ok then do
    say "UNEXPECTED_AUTH_SUCCESS"
    ignore = client~close
    exit 31
  end
  say "AUTH_REJECTED code=" || connected~code
  exit 0
end
if expectedMode == "SERVER_REJECT" then do
  if connected~ok then do
    say "UNEXPECTED_SERVER_AUTH_SUCCESS"
    ignore = client~close
    exit 40
  end
  say "SERVER_AUTH_REJECTED code=" || connected~code
  exit 0
end
if \connected~ok then do
  say "CONNECT_FAIL" connected~code connected~detail
  exit 32
end

if expectedMode == "RESPONSE_REJECT" then do
  probe = .directory~new
  probe["protocol"] = "fixture/1"
  probe["request_id"] = "forged-response"
  probe["operation"] = "STATUS"
  forged = client~requestJson(.json~toJson(probe))
  if forged~ok then do
    say "UNEXPECTED_FORGED_RESPONSE_ACCEPTED"
    ignore = client~close
    exit 41
  end
  say "RESPONSE_REJECTED code=" || forged~code
  exit 0
end

r1 = .directory~new
r1["protocol"] = "fixture/1"
r1["request_id"] = "socket-1"
r1["operation"] = "SNAPSHOT"
r1["principal"] = "AI_EVIL_BODY_CLAIM"
response1 = client~requestJson(.json~toJson(r1))
if \response1~ok then do
  say "REQUEST1_FAIL" response1~code response1~detail
  exit 33
end
d1 = .json~fromJson(response1~value)
if d1["authenticated_principal"] \== "AI_A" then exit 34
if d1["body_principal"] \== "AI_EVIL_BODY_CLAIM" then exit 35

r2 = .directory~new
r2["protocol"] = "fixture/1"
r2["request_id"] = "socket-2"
r2["operation"] = "STATUS"
response2 = client~requestJson(.json~toJson(r2))
if \response2~ok then do
  say "REQUEST2_FAIL" response2~code response2~detail
  exit 36
end
d2 = .json~fromJson(response2~value)
if d2["authenticated_principal"] \== "AI_A" then exit 37
if client~requestCount \= 2 then exit 38
closed = client~close
if \closed~ok then do
  say "CLOSE_FAIL" closed~code closed~detail
  exit 39
end
say "VALID_OK authenticated=" || d1["authenticated_principal"] || ";body_claim=" || d1["body_principal"] || ";requests=" || client~requestCount || ";state=" || client~state
exit 0

::requires "TerminalBrokerSocket.cls"
::requires "json.cls"
