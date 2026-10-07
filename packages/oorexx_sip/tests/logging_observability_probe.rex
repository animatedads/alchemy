service = .LogService~new("sip-observability-probe")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
sink = .SipAlchemyLogSink~new(service, .Log~INFO, .Log~INTERNAL)

server = .SipServer~new("127.0.0.1", 0, "oorexx-sip", "SHA-256", sink)
client = .SipUdpTransport~new("127.0.0.1", 0, sink)
crlf = "0d0a"x
request = "REGISTER sip:127.0.0.1 SIP/2.0" || crlf
request ||= "Via: SIP/2.0/UDP 127.0.0.1:" || client~bindPort || ";branch=z9hG4bKlogprobe;rport" || crlf
request ||= "Max-Forwards: 70" || crlf
request ||= "To: <sip:1001@127.0.0.1>" || crlf
request ||= "From: <sip:1001@127.0.0.1>;tag=logprobe" || crlf
request ||= "Call-ID: log-probe@localhost" || crlf
request ||= "CSeq: 1 REGISTER" || crlf
request ||= "Contact: <sip:1001@127.0.0.1:" || client~bindPort || ">;expires=300" || crlf
request ||= "User-Agent: logging-probe" || crlf
request ||= "Content-Length: 0" || crlf || crlf
sent = client~sendTo(request, "127.0.0.1", server~port)
event = server~poll(2)

needed = .array~of("SIP.TRANSPORT.BOUND", "SIP.WIRE.TX", "SIP.WIRE.RX", "SIP.ENGINE.EVENT", "SIP.REGISTRATION.BOUND")
seen = .directory~new
say "EVENT_COUNT" mem~count
do e over mem~events
  p = e~payload
  seen[p["eventType"]] = 1
  say p["eventType"] p["component"] p["objectId"]
end

do n over needed
  if \seen~hasIndex(n) then do
    say "FAIL missing" n
    exit 1
  end
end
if event[1] <> "registered" then do
  say "FAIL event" event[1]
  exit 1
end
say "PASS logging observability"
client~close
server~close
exit 0

::requires "sip.cls"
::requires "sip_logging.cls"
