service = .LogService~new("sip-auth-trace-probe")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
sink = .SipAlchemyLogSink~new(service, .Log~INFO, .Log~INTERNAL)
server = .SipServer~new("127.0.0.1", 0, "oorexx-sip", "SHA-256", sink)
server~credential("1001", "secret")
client = .SipUdpTransport~new("127.0.0.1", 0, sink)
registrar = "sip:127.0.0.1"
aor = "sip:1001@127.0.0.1"
contact = "sip:1001@127.0.0.1:" || client~bindPort
crlf = "0d0a"x

req1 = registerRequest(registrar, aor, contact, client~bindPort, 1, "")
sent = client~sendTo(req1, "127.0.0.1", server~port)
e1 = server~poll(2)
r1 = client~receive(2)
if e1[1] <> "register-challenge" then do; say "FAIL first" e1[1]; exit 1; end
challenge1 = sip_message_header(r1[1], "WWW-Authenticate")

bad = 'Digest username="1001", realm="oorexx-sip", nonce="bogus", uri="sip:127.0.0.1", response="deadbeef", algorithm=SHA-256, qop=auth, nc=00000001, cnonce="bad"'
req2 = registerRequest(registrar, aor, contact, client~bindPort, 2, bad)
sent = client~sendTo(req2, "127.0.0.1", server~port)
e2 = server~poll(2)
r2 = client~receive(2)
if e2[1] <> "register-challenge" then do; say "FAIL bad" e2[1]; exit 1; end
if e2[5] <> "nonce-mismatch" then do; say "FAIL reject reason" e2[5]; exit 1; end
challenge2 = sip_message_header(r2[1], "WWW-Authenticate")

auth = sip_digest_authorization(challenge2, "1001", "secret", "REGISTER", registrar)
req3 = registerRequest(registrar, aor, contact, client~bindPort, 3, auth)
sent = client~sendTo(req3, "127.0.0.1", server~port)
e3 = server~poll(2)
r3 = client~receive(2)
if e3[1] <> "registered" then do; say "FAIL accepted" e3[1]; exit 1; end

seen = .directory~new
do le over mem~events
  p = le~payload
  seen[p["eventType"]] = 1
  if p["eventType"]~left(8) = "SIP.AUTH" | p["eventType"]~left(16) = "SIP.REGISTRATION" then do
    say p["eventType"] "registrationId="p["registrationId"] "authorizationPresent="p["authorizationPresent"] "reason="p["reason"]
  end
end
needed = .array~of("SIP.AUTH.CHALLENGE", "SIP.AUTH.REJECTED", "SIP.AUTH.ACCEPTED", "SIP.REGISTRATION.BOUND")
do n over needed
  if \seen~hasIndex(n) then do; say "FAIL missing" n; exit 1; end
end
say "PASS auth trace challenge-reject-accept-bind"
client~close
server~close
exit 0

registerRequest: procedure
  use strict arg registrar, aor, contact, localPort, cseq, auth
  crlf = "0d0a"x
  r = "REGISTER" registrar "SIP/2.0" || crlf
  r ||= "Via: SIP/2.0/UDP 127.0.0.1:" || localPort || ";branch=z9hG4bKtrace" || cseq || ";rport" || crlf
  r ||= "Max-Forwards: 70" || crlf
  r ||= "To: <" || aor || ">" || crlf
  r ||= "From: <" || aor || ">;tag=trace" || crlf
  r ||= "Call-ID: auth-trace@localhost" || crlf
  r ||= "CSeq:" cseq "REGISTER" || crlf
  r ||= "Contact: <" || contact || ">;expires=300" || crlf
  if auth <> "" then r ||= "Authorization:" auth || crlf
  r ||= "Content-Length: 0" || crlf || crlf
  return r

::requires "sip.cls"
::requires "sip_logging.cls"
